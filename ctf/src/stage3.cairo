/// Stage 3
/// 
/// Welcome to the Tens Bank. Here, we feel great pride not only custodying your money 
/// but to do it in multiples of 10s. i.e The bank only accept deposits of 10 tokens whenever
/// you decide to deposit. so your balance must always be in multiples of 10. e.g 10, 20, 30,
/// 40, 60, 100, etc.
/// 
/// Just for fun, how do you ruin this perfect accounting system and make your balance any figure?
/// 
/// Relevant Addresses:
/// Stage 3 Contract Address: https://sepolia.starkscan.co/contract/0xed53ea834e8fad7b5399dfa90d2fe1e4415815f72c10199163f5e66af9216b
/// Deposit Token (CHA) Adddress: https://sepolia.starkscan.co/contract/0x26dbc5f09e101a5739eadbd526934cf92025c72ca0cd0f936cb6d82354844b5
/// Prize / Reward Token (PURR) Adddress: https://sepolia.starkscan.co/contract/0x5f3efe0b4493cd63bafb010fdcfcd58264d6f5aeed3a3fcac39870786ee406c
/// 
/// you can view all other addresses at `ctf/scripts/sepolia_deployment.ansi`
/// 
/// PRIZE:
/// 300 USD
/// 
/// YOU NEED TO HAVE SOLVED THE TWO PREVIOUS STAGES BEFORE ATTEMPTING THIS
/// 
/// 
use starknet::ContractAddress;

#[starknet::interface]
trait IStage3<TState> {
    fn deposit(ref self: TState);
    fn invariant_fails(self: @TState, addr: ContractAddress) -> bool;
}


#[starknet::contract]
mod Stage3 {
    use starknet::ContractAddress;
    use ctf::stage2::{IStage2Dispatcher, IStage2DispatcherTrait};
    use ctf::utils::{IERC20Dispatcher, IERC20DispatcherTrait};

    const VERSION: u8 = 0;

    const DEPOSIT_AMOUNT: u256 = 10;

    #[storage]
    struct Storage {
        stage2: IStage2Dispatcher,
        prize_token: IERC20Dispatcher,
        deposit_token: IERC20Dispatcher,
        deposit: LegacyMap<ContractAddress, u256>
    }

    #[abi(embed_v0)]
    impl Stage3 of super::IStage3<ContractState> {
        fn deposit(ref self: ContractState) {
            // Ensure that the caller has completed stage 1
            let caller = starknet::get_caller_address();
            assert!(self.stage2.read().drained(caller), "you have not solved stage 2");

            // Ensure that the caller has approved this contract to spend DEPOSIT_AMOUNT
            let deposit_token = self.deposit_token.read();
            let this = starknet::get_contract_address();
            assert!(
                deposit_token.allowance(caller, this) >= DEPOSIT_AMOUNT,
                "Stage 3: insufficient allowance: you only approved {} out of {}",
                deposit_token.allowance(caller, this),
                DEPOSIT_AMOUNT
            );

            // Transfer DEPOSIT_AMOUNT from caller to this contract
            assert!(
                deposit_token.transfer_from(caller, this, DEPOSIT_AMOUNT),
                "insufficient balance for deposit"
            );

            let caller_deposit = self.deposit.read(caller) + DEPOSIT_AMOUNT;
            self.deposit.write(caller, caller_deposit);

            if self.invariant_fails(caller) {
                // send prize to first winner
                let prize_token = self.prize_token.read();
                prize_token.transfer(caller, prize_token.balance_of(this));
            }
        }

        fn invariant_fails(self: @ContractState, addr: ContractAddress) -> bool {
            (self.deposit.read(addr) % DEPOSIT_AMOUNT).is_non_zero()
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        deposit_token: ContractAddress,
        prize_token: ContractAddress,
        stage2addr: ContractAddress
    ) {
        self.deposit_token.write(IERC20Dispatcher { contract_address: deposit_token });
        self.prize_token.write(IERC20Dispatcher { contract_address: prize_token });
        self.stage2.write(IStage2Dispatcher { contract_address: stage2addr });
    }
}

