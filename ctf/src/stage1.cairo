/// Challenge Description
/// Objective
/// 
/// The objective of this CTF to successfully navigate through all three stages 
/// of the ctf contracts and claim the prize associated with each round. 
/// 
/// Note that only the first person to solve a round will claim the prize.
/// The prize is automatically sent to you on sepolia if you win the challenge.

/// Stage 1
/// 
/// Your favorite charity is fundraising to help end world hunger. In their effort to
/// raise money, they have organised a dinner and have said that you must donate
/// a minimum of 500 Charity Coins(CHA) before you can attend this dinner. 
///
///  You can't afford to miss this dinner.
/// 
/// Notes: 
/// the donation_token ERC20 contract can be found in the `ctf::utils` file. It 
/// contains a mint function that let's you print Charity Coins (CHA) very slowly
/// 
/// Relevant Addresses:
/// Stage 1 Contract Address: https://sepolia.starkscan.co/contract/0x5036543fe098a2fdc3d8d7bfd2bdfed5388ea8dd2d1f1beb8367594a5038c5f
/// Donation Token (CHA) Adddress: https://sepolia.starkscan.co/contract/0x26dbc5f09e101a5739eadbd526934cf92025c72ca0cd0f936cb6d82354844b5
/// Prize Token (PURR) Adddress: https://sepolia.starkscan.co/contract/0x5f3efe0b4493cd63bafb010fdcfcd58264d6f5aeed3a3fcac39870786ee406c
/// 
/// you can view all other addresses at `ctf/scripts/sepolia_deployment.ansi`
/// 
/// PRIZE:
/// 50 USD

#[starknet::interface]
trait IStage1<TContractState> {
    fn donate(ref self: TContractState);
    fn donor(self: @TContractState, addr: starknet::ContractAddress) -> bool;
}


#[starknet::contract]
mod Stage1 {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::syscalls::deploy_syscall;
    use ctf::utils::{IERC20Dispatcher, IERC20DispatcherTrait};


    const VERSION: u8 = 0;


    // 500 * (10 ** 18) // 500 * 10 ^ 18
    const REQUIRED_DONATION_AMOUNT: u256 = 500_000_000_000_000_000_000;

    #[storage]
    struct Storage {
        prize_token: IERC20Dispatcher,
        donation_token: IERC20Dispatcher,
        donor: LegacyMap<ContractAddress, bool>
    }

    #[abi(embed_v0)]
    impl Stage1Impl of super::IStage1<ContractState> {
        fn donate(ref self: ContractState) {
            // Ensure that the caller has approved this contract to spend REQUIRED_DONATION_AMOUNT
            let donation_token = self.donation_token.read();
            let caller = starknet::get_caller_address();
            let this = starknet::get_contract_address();
            assert!(
                donation_token.allowance(caller, this) >= REQUIRED_DONATION_AMOUNT,
                "Stage 1: insufficient allowance: you only approved {} out of {}",
                donation_token.allowance(caller, this),
                REQUIRED_DONATION_AMOUNT
            );

            // Transfer REQUIRED_DONATION_AMOUNT from caller to this contract
            donation_token.transfer_from(caller, this, REQUIRED_DONATION_AMOUNT);

            // add caller as donor
            self.donor.write(caller, true);

            // send prize to first winner
            let prize_token = self.prize_token.read();
            prize_token.transfer(caller, prize_token.balance_of(this));
        }

        fn donor(self: @ContractState, addr: ContractAddress) -> bool {
            self.donor.read(addr)
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, donation_token: ContractAddress, prize_token: ContractAddress
    ) {
        self.donation_token.write(IERC20Dispatcher { contract_address: donation_token });
        self.prize_token.write(IERC20Dispatcher { contract_address: prize_token });
    }
}
