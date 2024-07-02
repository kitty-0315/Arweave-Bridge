local bint = require(".bint")(256)
local ao = require("ao")
local json = require("json")

if not Balances then
    Balances = {}
end

if Name ~= "Aweare Wrapped ETH" then
    Name = "Aweare Wrapped ETH"
end

if Ticker ~= "awETH" then
    Ticker = "awETH"
end

if Denomination ~= 6 then
    Denomination = 6
end

if not Logo then
    Logo = "TXID of logo image"
end

if AdminAddr ~= "s_n4Fgz_Pr50OtJMfZbw54MqnrMqCdQTgMV4-omFDDc" then
    AdminAddr = "s_n4Fgz_Pr50OtJMfZbw54MqnrMqCdQTgMV4-omFDDc"
end

--[[
    Info
    ]]
--
Handlers.add("info", Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send({
        Target = msg.From,
        Tags = {
            Name = Name,
            Ticker = Ticker,
            Logo = Logo,
            Denomination = tostring(Denomination),
            AdminAddr = AdminAddr
        }
    })
end)

--[[
     Balances
   ]]
--
Handlers.add("balances", Handlers.utils.hasMatchingTag("Action", "Balances"), function(msg)
    ao.send({
        Target = msg.From,
        Data = json.encode(Balances)
    })
end)

--[[
     Balance
   ]]
--
Handlers.add("balance", Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
    local bal = "0"

    -- If not Recipient is provided, then return the Senders balance
    if (msg.Tags.Recipient and Balances[msg.Tags.Recipient]) then
        bal = Balances[msg.Tags.Recipient]
    elseif Balances[msg.From] then
        bal = Balances[msg.From]
    end

    ao.send({
        Target = msg.From,
        Balance = bal,
        Ticker = Ticker,
        Account = msg.Tags.Recipient or msg.From,
        Data = bal
    })
end)

--[[
     Transfer
   ]]
--
Handlers.add("transfer", Handlers.utils.hasMatchingTag("Action", "Transfer"), function(msg)
    assert(type(msg.Recipient) == "string", "Recipient is required!")
    assert(type(msg.Quantity) == "string", "Quantity is required!")
    assert(bint.__lt(0, bint(msg.Quantity)), "Quantity must be greater than 0")

    if not Balances[msg.From] then
        Balances[msg.From] = "0"
    end
    if not Balances[msg.Recipient] then
        Balances[msg.Recipient] = "0"
    end

    local qty = bint(msg.Quantity)
    local balance = bint(Balances[msg.From])
    if bint.__le(qty, balance) then
        Balances[msg.From] = tostring(bint.__sub(balance, qty))
        Balances[msg.Recipient] = tostring(bint.__add(Balances[msg.Recipient], qty))

        --[[
         Only send the notifications to the Sender and Recipient
         if the Cast tag is not set on the Transfer message
       ]]
        --
        if not msg.Cast then
            -- Send Debit-Notice to the Sender
            ao.send({
                Target = msg.From,
                Action = "Debit-Notice",
                Recipient = msg.Recipient,
                Quantity = tostring(qty),
                Data = Colors.gray .. "You transferred " .. Colors.blue .. msg.Quantity .. Colors.gray .. " to " ..
                    Colors.green .. msg.Recipient .. Colors.reset
            })
            -- Send Credit-Notice to the Recipient
            ao.send({
                Target = msg.Recipient,
                Action = "Credit-Notice",
                Sender = msg.From,
                Quantity = tostring(qty),
                Data = Colors.gray .. "You received " .. Colors.blue .. msg.Quantity .. Colors.gray .. " from " ..
                    Colors.green .. msg.Recipient .. Colors.reset
            })
        end
    else
        ao.send({
            Target = msg.From,
            Action = "Transfer-Error",
            ["Message-Id"] = msg.Id,
            Error = "Insufficient Balance!"
        })
    end
end)

--[[
    Mint
   ]]
--
Handlers.add("mint", Handlers.utils.hasMatchingTag("Action", "Mint"), function(msg)
    assert(type(msg.Quantity) == "string", "Quantity is required!")
    assert(type(msg.Address) == "string", "Address required!")
    assert(type(msg.MemId) == "string", "MemId is Required!")
    assert(MemIds[msg.MemId] == nil, "MemId already exists!")
    assert(bint.__lt(0, msg.Quantity), "Quantity must be greater than zero!")

    local address = msg.Address
    if not Balances[address] then
        Balances[address] = "0"
    end

    if msg.From == AdminAddr then
        Balances[address] = tostring(bint.__add(Balances[address], msg.Quantity))
        MemIds[msg.MemId] = true

        ao.send({
            Target = address,
            Data = Colors.gray .. "Successfully minted " .. Colors.blue .. msg.Quantity .. Colors.reset
        })
    else
        ao.send({
            Target = address,
            Action = "Mint-Error",
            ["Message-Id"] = msg.Id,
            Error = "Only the Bridge Admin can mint new " .. Ticker .. " tokens!"
        })
    end
end)

--[[
     Burn
   ]]
--
Handlers.add("burn", Handlers.utils.hasMatchingTag("Action", "Burn"), function(msg)
    assert(type(msg.Quantity) == "string", "Quantity is required!")
    assert(bint.__lt(0, bint(msg.Quantity)), "Quantity must be greater than 0")
    assert(type(msg.MemTarget) == "string", "Target is required!")

    local qty = bint(msg.Quantity)
    local balance = bint(Balances[msg.From])
    if bint.__le(qty, balance) then
        Balances[msg.From] = tostring(bint.__sub(balance, qty))

        BurnReqs[msg.Id] = {
            qty = tostring(qty),
            caller = msg.From,
            mem_target = msg.MemTarget
        }

        --[[
         Only send the notifications to the Sender
         if the Cast tag is not set on the Burn message
       ]]
        --
        if not msg.Cast then
            -- Send Burn-Notice to the Sender
            ao.send({
                Target = msg.From,
                Action = "Burn-Notice",
                Quantity = tostring(qty),
                Data = Colors.gray .. "You Burned " .. Colors.blue .. msg.Quantity
            })
        end
    else
        ao.send({
            Target = msg.From,
            Action = "Burn-Error",
            ["Message-Id"] = msg.Id,
            Error = "Insufficient Balance!"
        })
    end
end)
