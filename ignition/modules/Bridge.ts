import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const BridgeModule = buildModule("Bridge", (m) => {

  const bridge = m.contract("AoBridgeETH", [
    "0x0FaCf846af22BCE1C7f88D1d55A038F27747eD2B",
    "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    "0x57E2E2E06Fb0dDc9B9C65309a8ed33F138328180",
    "0x57E2E2E06Fb0dDc9B9C65309a8ed33F138328180",
    "a8356f48569c434eaa4ac5fcb4db5cc0",
    "http://135.181.160.39:3000/",
    "1000",
    "1",
    "1000",
    "3000",
  ]);

  return { bridge };
});

export default BridgeModule;
