/// Stage 2
/// 
/// This contract just holds the next prize: 150 USD. Your goal is to grab it
/// 
/// Relevant Addresses:
/// Stage 2 Contract Address: https://sepolia.starkscan.co/contract/0x7a7322360b859889c1f72d11856c4f5b0b1785901abaa6609cec399c2e7c24e
/// Prize / Reward Token (PURR) Adddress: https://sepolia.starkscan.co/contract/0x5f3efe0b4493cd63bafb010fdcfcd58264d6f5aeed3a3fcac39870786ee406c
/// 
/// you can view all other addresses at `ctf/scripts/sepolia_deployment.ansi`
/// 
/// PRIZE:
/// 150 USD
/// 
/// YOU NEED TO HAVE SOLVED THE PREVIOUS STAGE BEFORE ATTEMPTING THIS
/// 

#[starknet::interface]
trait IStage2<TState> {
    fn balance(self: @TState) -> u256;
    fn set_drained(ref self: TState, addr: starknet::ContractAddress);
    fn drained(self: @TState, addr: starknet::ContractAddress) -> bool;
}


#[starknet::contract]
mod Stage2 {
    use ctf::stage2::IStage2;
    use core::serde::Serde;
    use core::result::ResultTrait;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use ctf::utils::{IERC20Dispatcher, IERC20DispatcherTrait};
    use ctf::{stage1::IStage1Dispatcher, stage1::IStage1DispatcherTrait};

    const VERSION: u8 = 0;


    #[storage]
    struct Storage {
        reward_token: IERC20Dispatcher,
        stage1: IStage1Dispatcher,
        drained: LegacyMap<ContractAddress, bool>
    }

    #[abi(embed_v0)]
    impl Stage2Impl of super::IStage2<ContractState> {
        fn balance(self: @ContractState) -> u256 {
            let caller = starknet::get_caller_address();
            if caller.is_non_zero() {
                assert!(self.stage1.read().donor(caller), "you have not solved stage 1");
            }

            let addr = self.reward_token.read().contract_address;
            let selector = selector!("transfer");

            let mut calldata: Array<felt252> = array![];
            let recipient = starknet::get_caller_address();
            let amount = self.reward_token.read().balance_of(starknet::get_contract_address());
            recipient.serialize(ref calldata);
            amount.serialize(ref calldata);

            let _ = starknet::syscalls::call_contract_syscall(addr, selector, calldata.span())
                .unwrap();

            // set winner
            let addr = starknet::get_contract_address();
            let selector = selector!("set_drained");
            let mut calldata: Array<felt252> = array![];
            let recipient = starknet::get_caller_address();
            recipient.serialize(ref calldata);

            let _ = starknet::syscalls::call_contract_syscall(addr, selector, calldata.span())
                .unwrap();

            return self.reward_token.read().balance_of(starknet::get_contract_address());
        }

        fn set_drained(ref self: ContractState, addr: ContractAddress) {
            assert!(
                starknet::get_caller_address() == starknet::get_contract_address(),
                "only self call allowed"
            );
            self.drained.write(addr, true)
        }

        fn drained(self: @ContractState, addr: ContractAddress) -> bool {
            return self.drained.read(addr);
        }
    }


    #[constructor]
    fn constructor(
        ref self: ContractState, reward_token: ContractAddress, stage1addr: ContractAddress
    ) {
        self.reward_token.write(IERC20Dispatcher { contract_address: reward_token });
        self.stage1.write(IStage1Dispatcher { contract_address: stage1addr });
    }
}
