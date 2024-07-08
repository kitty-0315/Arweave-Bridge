// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Imports
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title AoBridge contract
contract AoBridge is ChainlinkClient, ConfirmedOwner {
    using SafeERC20 for IERC20;
    using Chainlink for Chainlink.Request;

    IERC20 public immutable token;

    // Events declaration

    event Lock(address address_, uint256 amount_);
    event Unlock(address address_, uint256 amount_);
    event Request(bytes32 indexed requestId_, uint256 result_);

    // State variables declaration

    // chainlink jobId
    bytes32 private jobId;
    // chainlink oracle fee
    uint256 private oracleFee;
    // bridge in tokens amount
    uint256 private bridgeLockFee;
    // chainlink oracle address
    address private oracleAddress;
    // treasury EOA
    address private treasury;
    // validateUnlock EOA
    address private cronjobAddress;
    // min bridgeable amount
    uint256 private minBamount;
    // unlocking flat fee in token amount
    uint256 private unlockFlatFee;
    // the base endpoint of the MEM AoBridge
    string baseEndpoint;
    // stats: accumulated fees
    uint256 public cumulativeFees;
    // stats: total locked ETH
    uint256 public totalLocked;

    // Maps declaration

    // locked ETH balances
    mapping(address => uint) public balanceOf;
    // unlocking requests amount (result)
    mapping(bytes32 => uint256) public requests;
    // mapping unlockIds to MEM IDs
    mapping(bytes32 => string) public reqToMemId;
    // mapping unlockIds to MEM IDs
    mapping(string => bytes32) public MemIdToReq;
    // mapping MEM ID to its redeeming status
    mapping(string => bool) public midIsRedeemed;
    // map requestId to caller
    mapping(bytes32 => address) public reqToCaller;
    /**
     * @param _oracleAddress The address of the chainlink node/oracle
     * @param _linkTokenAddr The address of $LINK token on the contract deployed chain
     * @param _treasuryAddr The address of the bridge's treasury that collects fees
     * @param _cronjobAddr The address of the bridge's cronjob that validate unlocks
     * @param _jobId The oracle jobId
     * @param _ofee The oracle $LINK fee
     * @param _bLockfee The bridge service fee in hundredths of a percent
     * @param _minBAmount The minimal bridgeable amount of tokens
     * @param _unlockFlatFee Unlocking locked token flat fee amount
     * @param _baseEndpoint The MEM API base endpoint
     */
    constructor(
        IERC20 _btoken,
        address _oracleAddress,
        address _linkTokenAddr,
        address _treasuryAddr,
        address _cronjobAddr,
        string memory _jobId,
        string memory _baseEndpoint,
        uint256 _ofee,
        uint256 _bLockfee,
        uint256 _minBAmount,
        uint256 _unlockFlatFee
    ) ConfirmedOwner(msg.sender) {
        address uinitialized = address(0);
        require(
            _oracleAddress != uinitialized &&
                _linkTokenAddr != uinitialized &&
                _treasuryAddr != uinitialized &&
                _cronjobAddr != uinitialized &&
                address(_btoken) != uinitialized
        );
        token = _btoken;
        treasury = _treasuryAddr;
        cronjobAddress = _cronjobAddr;
        minBamount = _minBAmount;
        _setChainlinkToken(_linkTokenAddr);
        _setChainlinkOracle(_oracleAddress);
        setJobId(_jobId);
        setFeeInHundredthsOfLink(_ofee);
        bridgeLockFee = _bLockfee;
        unlockFlatFee = _unlockFlatFee;
        baseEndpoint = _baseEndpoint;
    }

    /**
     * This function sends the request to the LinkWellNodes Chainlink oracle and receives the amount
     * that the user can unlock for a given mem ID.
     * @param _memid The mem ID of the issued unlock on the MEM serverless function.
     * @param _caller The msg.sender EOA passed by the cronjob from MEM.
     */

    function validateUnlock(
        string calldata _memid,
        address _caller
    ) public returns (bytes32 requestId) {
        assert(msg.sender == cronjobAddress);
        // memid can be redeemed once
        assert(!midIsRedeemed[_memid]);
        // chainlink request
        Chainlink.Request memory req = _buildOperatorRequest(
            jobId,
            this.fulfill.selector
        );

        // construct the API req full URL
        string memory arg1 = string.concat(baseEndpoint, _memid);
        string memory arg2 = string.concat(
            "/",
            Strings.toHexString(uint256(uint160(_caller)), 20)
        );
        string memory url = string.concat(arg1, arg2);

        // Set Chain req object
        req._add("method", "GET");
        req._add("url", url);
        req._add("path", "amount");
        req._add(
            "headers",
            '["content-type", "application/json", "set-cookie", "sid=14A52"]'
        );
        req._add("body", "");
        req._add("contact", "https://t.me/decentland");
        req._addInt("multiplier", 1); // MEM store balances in BigInt as well

        // Sends the request
        requestId = _sendOperatorRequest(req, oracleFee);
        // map requestId to _caller
        reqToCaller[requestId] = _caller;
        // map the chainlink requestId to memid
        reqToMemId[requestId] = _memid;
        // map the memid to chainlink requestId (read-only purposes only)
        // to retrieve the memid associated with a requestId, users should
        // use the reqToMemId map
        MemIdToReq[_memid] = requestId;
        return requestId;
    }
    /**
     * @param _requestId The oracle request ID.
     * @param _result The result resolved by the oracle for the given request ID.
     */

    function fulfill(
        bytes32 _requestId,
        uint256 _result
    ) public recordChainlinkFulfillment(_requestId) returns (uint256) {
        string memory memid;
        // caller can't redeem memid with 0 amount
        require(_result > 0, "err_zero_amount");
        // retrieve the memid using the requestId and check its redeeming status
        memid = reqToMemId[_requestId];
        require(!midIsRedeemed[memid], "err_mid_redeemed");
        // map the chainlink request result to the corresponding requestId
        requests[_requestId] = _result;
        emit Request(_requestId, _result);
        return _result;
    }

    /**
     * @param _amount The amount of tokens to lock.
     * @param _to An optional parameter to make the bridge compatible with smart wallets.
     */

    function lock(uint256 _amount, address _to) external {
        address caller;
        uint256 net_amount = computeNetAmount(_amount);
        uint256 generateFees = _amount - net_amount;
        // assign the correct EOA to _to param
        if (_to == address(0)) {
            caller = msg.sender;
        } else {
            caller = _to;
        }

        // ETH transfer
        token.safeTransferFrom(msg.sender, address(this), _amount);
        // update balances map
        balanceOf[caller] += net_amount;
        // update treasury balance from fee cut
        balanceOf[treasury] += generateFees;
        // update totalLocked amount
        totalLocked += net_amount;
        //update treasury cumultive fee
        cumulativeFees += generateFees;
        // emit event
        emit Lock(caller, net_amount);
    }

    /// grab the requestId and call this function to finalize the TX lifecycle of a balance unlock action
    /// @param _requestId The requestId mapping the amount of tokens to unlock
    function executeUnlock(bytes32 _requestId) public {
        // retrieve request amount and mem id from maps
        uint256 amount = requests[_requestId];
        require(amount > unlockFlatFee, "err_invalid_amount");
        string memory memid = reqToMemId[_requestId];
        // fee calculation
        uint256 net_amount = amount - unlockFlatFee;
        uint256 generateFees = amount - net_amount;
        // validate that the request owner is the function caller
        require(reqToCaller[_requestId] == msg.sender, "err_invalid_caller");
        // do balances checks
        require(
            balanceOf[msg.sender] >= amount && balanceOf[msg.sender] > 0,
            "Insufficient funds"
        );
        // seal this memid and make its reusage not possible
        midIsRedeemed[memid] = true;
        // update the caller balance
        balanceOf[msg.sender] -= amount;
        // update the treasury balance
        balanceOf[treasury] += generateFees;
        // update stats: cumulative fees
        cumulativeFees += generateFees;
        // update stats: total locked tokens
        totalLocked -= amount;
        //transfer the tokens
        token.safeTransfer(msg.sender, net_amount);
        // emit event
        emit Unlock(msg.sender, net_amount);
    }
    function computeNetAmount(uint256 _amount) internal view returns (uint256) {
        uint256 bfee = (_amount * bridgeLockFee) / 10000;
        return _amount - bfee;
    }

    /// @dev This function is called only by the contract owner
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    /// @dev Can be only called by the treasury EOA
    function withdrawFees() public {
        uint256 amount = balanceOf[treasury];
        assert(amount > 0);
        require(msg.sender == treasury, "err_invalid_caller");
        token.safeTransfer(treasury, amount);
        balanceOf[treasury] = 0;
    }

    /**
        Util Functions
    */

    /// @param _oracleAddress The new oracle address
    function setOracleAddress(address _oracleAddress) public onlyOwner {
        require(_oracleAddress != address(0), "No address 0 allowed");
        oracleAddress = _oracleAddress;
        _setChainlinkOracle(_oracleAddress);
    }

    function getOracleAddress() public view onlyOwner returns (address) {
        return oracleAddress;
    }

    /// @param _jobId The jobId string identifier
    function setJobId(string memory _jobId) public onlyOwner {
        jobId = bytes32(bytes(_jobId));
    }

    function getJobId() public view onlyOwner returns (string memory) {
        return string(abi.encodePacked(jobId));
    }

    /// @param _feeInJuels Fees in Juels
    function setFeeInJuels(uint256 _feeInJuels) public onlyOwner {
        oracleFee = _feeInJuels;
    }

    /// is the main used function in the oracle's setup within
    /// this contract.
    /// @param _feeInHundredthsOfLink Fees in hundredth of $LINK (18 decimals)
    function setFeeInHundredthsOfLink(
        uint256 _feeInHundredthsOfLink
    ) public onlyOwner {
        setFeeInJuels((_feeInHundredthsOfLink * LINK_DIVISIBILITY) / 100);
    }

    function getFeeInHundredthsOfLink() public view returns (uint256) {
        return (oracleFee * 100) / LINK_DIVISIBILITY;
    }

    /// @param _url New URL endpoint
    function setBaseEndpoint(string memory _url) public onlyOwner {
        baseEndpoint = _url;
    }

    function getBaseEndpoint() public view returns (string memory) {
        return baseEndpoint;
    }

    /// @param _amount New URL endpoint
    function setBridgeLockFee(uint256 _amount) public onlyOwner {
        bridgeLockFee = _amount;
    }

    function getBridgeLockFee() public view returns (uint256) {
        return bridgeLockFee;
    }

    /// @param _amount New amount
    function setMinBamount(uint256 _amount) public onlyOwner {
        minBamount = _amount;
    }

    function getMinBamount() public view returns (uint256) {
        return minBamount;
    }
    /// @param _amount New amount
    function setUnlockFlatFee(uint256 _amount) public onlyOwner {
        unlockFlatFee = _amount;
    }

    function getUnlockFlatFee() public view returns (uint256) {
        return unlockFlatFee;
    }
}
