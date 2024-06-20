import colors from "colors";
import {  deployERC20, deployPrizeERC20, deployStage1, deployStage2, deployStage3, sendPrize } from "./libs/contract.js";

const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay));

const main = async () => {
  console.log(`   ____          _         `.red);
  console.log(`  |    \\ ___ ___| |___ _ _ `.red);
  console.log(`  |  |  | -_| . | | . | | |`.red);
  console.log(`  |____/|___|  _|_|___|_  |`.red);
  console.log(`            |_|       |___|`.red);

  let prize_token_address = await deployPrizeERC20(process.env.STARKNET_ACCOUNT_ADDRESS);
  let free_mint_token_address = await deployERC20("Charity", "CHA");

  let stage1_address = await deployStage1(free_mint_token_address, prize_token_address);
  await sendPrize(prize_token_address, stage1_address, 50n * 10n ** 18n);
  await sleep(10_000);

  let stage2_address = await deployStage2(prize_token_address, stage1_address);
  await sendPrize(prize_token_address, stage2_address, 150n * 10n ** 18n);
  await sleep(10_000);

  let stage3_address = await deployStage3(free_mint_token_address, prize_token_address, stage2_address);
  await sendPrize(prize_token_address, stage3_address, 300n * 10n ** 18n);
}

main();
