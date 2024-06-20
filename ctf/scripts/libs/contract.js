import "dotenv/config";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import { json } from "starknet";
import { getNetwork, getAccount } from "./network.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TARGET_PATH = path.join(__dirname, "..", "..", "target", "release");

const getContracts = () => {
  if (!fs.existsSync(TARGET_PATH)) {
    throw new Error(`Target directory not found at path: ${TARGET_PATH}`);
  }
  const contracts = fs
    .readdirSync(TARGET_PATH)
    .filter((contract) => contract.includes(".contract_class.json"));
  if (contracts.length === 0) {
    throw new Error("No build files found. Run `scarb build` first");
  }
  return contracts;
};

const getPath = (contract_name) => {
  const contracts = getContracts();
  const c = contracts.find((contract) =>
    contract.includes(contract_name),
  );
  if (!c) {
    throw new Error(`Contract not found: ${contract_name}`);
  }
  return path.join(TARGET_PATH, c);
};


const declare = async (filepath, contract_name) => {
  console.log(`\nDeclaring ${contract_name}...\n\n`.magenta);
  const compiledSierraCasm = filepath.replace(
    ".contract_class.json",
    ".compiled_contract_class.json",
  );
  const compiledFile = json.parse(fs.readFileSync(filepath).toString("ascii"));
  const compiledSierraCasmFile = json.parse(
    fs.readFileSync(compiledSierraCasm).toString("ascii"),
  );
  const account = getAccount();
  const contract = await account.declareIfNot({
    contract: compiledFile,
    casm: compiledSierraCasmFile,
  });

  const network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(`- Class Hash: `.magenta, `${contract.class_hash}`);
  if (contract.transaction_hash) {
    console.log(
      "- Tx Hash: ".magenta,
      `${network.explorer_url}/tx/${contract.transaction_hash})`,
    );
    await account.waitForTransaction(contract.transaction_hash);
  } else {
    console.log("- Tx Hash: ".magenta, "Already declared");
  }

  return contract;
};

export const sendPrize = async (prizeAddress, recipient, amount) => {
  ///////////////////////////////////////////
  ///////     Send Prize         ////////////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  try {
    let res = await account.execute({
      contractAddress: prizeAddress,
      entrypoint: "mint",
      calldata: [recipient, amount, 0],
    });
    console.log(` \n\n Minting ${amount} prize tokens to ${recipient}`);
    console.log(` \n\n ${res}`);

  } catch (err) {
    console.log(err);
    console.log("Something went wrong man", );
  }
};




export const deployPrizeERC20 = async (owner) => {
  ///////////////////////////////////////////
  /////// DEPLOY PRIZE ERC20 Contract  ////////////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  // declare contract
  let name = "Prize";
  const class_hash = (await declare(getPath(name), name)).class_hash;

  let constructorCalldata = [owner];

  // Deploy contract
  console.log(`\nDeploying CTF Prize (PURR) ERC20 Token ... \n\n`.green);
  let contract = await account.deployContract({
    classHash: class_hash,
    constructorCalldata: constructorCalldata,
  });

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  let a = await account.waitForTransaction(contract.transaction_hash);
  console.log("Contract Address: ".green, contract.address, "\n\n");

  return contract.address;
};


export const deployERC20 = async(token_name, token_symbol) => {

  ///////////////////////////////////////////
  /////// DEPLOY ERC20 Contract  ////////////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  // declare contract
  let name = "ERC20"
  const class_hash
    = (await declare(getPath(name), name)).class_hash;

  let constructorCalldata = [
    token_name,
    token_symbol,
  ]
  
  // Deploy contract
  console.log(`\nDeploying ${token_name} (${token_symbol}) ${name} ... \n\n`.green);
  let contract = await account.deployContract({
    classHash: class_hash,
    constructorCalldata: constructorCalldata
  });


  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`,
  );
  let a = await account.waitForTransaction(contract.transaction_hash);
  console.log("Contract Address: ".green, contract.address, "\n\n");

  return contract.address
}








export const deployStage1 = async (donation_token, prize_token) => {
  ///////////////////////////////////////////
  ///////       DEPLOY Stage 1         //////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  // declare contract
  let name = "Stage1";
  const class_hash = (await declare(getPath(name), name)).class_hash;

  let constructorCalldata = [donation_token, prize_token];

  // Deploy contract
  console.log(`\nDeploying ${name} ... \n\n`.green);
  let contract = await account.deployContract({
    classHash: class_hash,
    constructorCalldata: constructorCalldata,
  });

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  let a = await account.waitForTransaction(contract.transaction_hash);
  console.log("Contract Address: ".green, contract.address, "\n\n");

  return contract.address;
};



export const deployStage2 = async (prize_token_address, stage1_address) => {
  ///////////////////////////////////////////
  ///////       DEPLOY Stage 2         //////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  // declare contract
  let name = "Stage2";
  const class_hash = (await declare(getPath(name), name)).class_hash;

  let constructorCalldata = [prize_token_address, stage1_address];

  // Deploy contract
  console.log(`\nDeploying ${name} ... \n\n`.green);
  let contract = await account.deployContract({
    classHash: class_hash,
    constructorCalldata: constructorCalldata,
  });

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  let a = await account.waitForTransaction(contract.transaction_hash);
  console.log("Contract Address: ".green, contract.address, "\n\n");

  return contract.address;
};



export const deployStage3 = async (
  deposit_token_address, prize_token_address,
  stage2_address
) => {
  ///////////////////////////////////////////
  ///////       DEPLOY Stage 3         //////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  // declare contract
  let name = "Stage3";
  const class_hash = (await declare(getPath(name), name)).class_hash;

  let constructorCalldata = [deposit_token_address, prize_token_address, stage2_address];

  // Deploy contract
  console.log(`\nDeploying ${name} ... \n\n`.green);
  let contract = await account.deployContract({
    classHash: class_hash,
    constructorCalldata: constructorCalldata,
  });

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  let a = await account.waitForTransaction(contract.transaction_hash);
  console.log("Contract Address: ".green, contract.address, "\n\n");

  return contract.address;
};
;