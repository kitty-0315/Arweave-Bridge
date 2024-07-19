export const ETH_TOKEN_BRIDGE =
  "0xcE92ECFE82acB4806D99268E0470B832d9616852";
export const MEM_ORACLE_ID = `FP_8isx3lBvBXrXMiFn86HZnHKAgc1Yu1BqTb_XZSG8`;
export const AO_PROCESS_ID = `hfa2INNASU1pVAn2p6878ohsOch8x0kwRzXhGVacWAo`; // eth-to-usd

export const RPC_URL = `https://rpc.sepolia.org/`;

export const BRIDGE_ABI = [
  "function validateUnlock(string calldata _memid, address _caller) public returns (bytes32 requestId)",
];


export const BRIDGES_CONTRACTS = {
  "0xcE92ECFE82acB4806D99268E0470B832d9616852": {
    name: "usdc_token",
    decimals: 1e6,
  },
};