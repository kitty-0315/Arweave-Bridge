export const ETH_TOKEN_BRIDGE =
  "0xf1c3995bC0E07b161E59B5D43901C64703e44Efa";
export const MEM_ORACLE_ID = `BompigyZ5dHdQP3fPLw_aMxmEsOGJ3uMPfhzmsLAcfI`;
export const AO_PROCESS_ID = `Ihe78gGT4BQWGjIfElOqw14M0HaODNI6yjy9YM1Xais`; // eth-to-usd

export const RPC_URL = `https://rpc.sepolia.org/`;

export const BRIDGE_ABI = [
  "function validateUnlock(string calldata _memid, address _caller) public returns (bytes32 requestId)",
];


export const BRIDGES_CONTRACTS = {
  "0xf1c3995bC0E07b161E59B5D43901C64703e44Efa": {
    name: "usdc_token",
    decimals: 1e6,
  },
};