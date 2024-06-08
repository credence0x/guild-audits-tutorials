#[starknet::interface]
trait IERC20Mint<TContractState> {
    /// Allows the caller mint 1 token at a time
    fn mint(ref self: TContractState);
}


#[starknet::contract]
mod ERC20 {
    use integer::BoundedInt;
    use openzeppelin::token::erc20::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC20_name: ByteArray,
        ERC20_symbol: ByteArray,
        ERC20_total_supply: u256,
        ERC20_balances: LegacyMap<ContractAddress, u256>,
        ERC20_allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    /// Emitted when tokens are moved from address `from` to address `to`.
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256
    }

    /// Emitted when the allowance of a `spender` for an `owner` is set by a call
    /// to `approve`. `value` is the new allowance.
    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256
    }

    mod Errors {
        const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
        const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
        const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
    }

    //
    // External
    //

    #[abi(embed_v0)]
    impl ERC20Impl of interface::IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.ERC20_total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.ERC20_balances.read(account)
        }


        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.ERC20_allowances.read((owner, spender))
        }


        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount)
        }


        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
    }

    impl ERC20MetadataImpl of interface::IERC20Metadata<ContractState> {
        /// Returns the name of the token.
        fn name(self: @ContractState) -> ByteArray {
            self.ERC20_name.read()
        }

        /// Returns the ticker symbol of the token, usually a shorter version of the name.
        fn symbol(self: @ContractState) -> ByteArray {
            self.ERC20_symbol.read()
        }

        /// Returns the number of decimals used to get its user representation.
        fn decimals(self: @ContractState) -> u8 {
            18
        }
    }


    impl ERC20MintImpl of super::IERC20Mint<ContractState> {
        fn mint(ref self: ContractState) {
            self._mint(starknet::get_caller_address(), 1)
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.ERC20_name.write(name);
        self.ERC20_symbol.write(symbol);
    }


    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!recipient.is_zero(), Errors::TRANSFER_TO_ZERO);
            if amount > self.ERC20_balances.read(sender) {
                return false;
            }
            self.ERC20_balances.write(sender, self.ERC20_balances.read(sender) - amount);
            self.ERC20_balances.write(recipient, self.ERC20_balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
            return true;
        }


        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), Errors::APPROVE_FROM_ZERO);
            assert(!spender.is_zero(), Errors::APPROVE_TO_ZERO);
            self.ERC20_allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }


        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), Errors::MINT_TO_ZERO);
            self.ERC20_total_supply.write(self.ERC20_total_supply.read() + amount);
            self.ERC20_balances.write(recipient, self.ERC20_balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }


        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.ERC20_allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}


#[starknet::interface]
trait ISwiper<TContractState> {
    fn swipe(ref self: TContractState);
    fn solved(self: @TContractState) -> bool;
}


#[starknet::contract]
mod Swiper {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::syscalls::deploy_syscall;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // 500,000,000,000 * (10 ** 18) // 500 billion * 10 ^ 18
    const REQUIRED_TOKEN_AMOUNT: u256 = 500000000000000000000000000000;

    #[storage]
    struct Storage {
        token: IERC20Dispatcher,
        solved: bool
    }

    #[abi(embed_v0)]
    impl SwiperImpl of super::ISwiper<ContractState> {
        fn swipe(ref self: ContractState) {
            // Ensure that the caller has approved this contract to spend REQUIRED_TOKEN_AMOUNT
            let token = self.token.read();
            let caller = starknet::get_caller_address();
            let this = starknet::get_contract_address();
            assert!(
                token.allowance(caller, this) >= REQUIRED_TOKEN_AMOUNT,
                "Swiper: insufficient allowance: you only approved {} out of {}",
                token.allowance(caller, this),
                REQUIRED_TOKEN_AMOUNT
            );

            // Transfer REQUIRED_TOKEN_AMOUNT from caller to this contract
            token.transfer_from(caller, this, REQUIRED_TOKEN_AMOUNT);

            self.solved.write(true);
        }

        fn solved(self: @ContractState) -> bool {
            self.solved.read()
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress) {
        self.token.write(IERC20Dispatcher { contract_address: token });
    }
}


#[cfg(test)]
mod test {
    use core::serde::Serde;
    use super::{
        ISwiper, ISwiperDispatcher, ISwiperDispatcherTrait, Swiper, Swiper::REQUIRED_TOKEN_AMOUNT
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use snforge_std::{
        declare, ContractClassTrait, spy_events, SpyOn, EventSpy, EventAssertions, test_address,
        start_roll, stop_roll, start_warp, stop_warp, CheatTarget, start_prank, stop_prank
    };
    use starknet::ContractAddress;

    fn USDC_TOKEN_MOCK() -> IERC20Dispatcher {
        let usdc_contract = declare("ERC20").unwrap();
        let name: ByteArray = "USDC Token";
        let symbol: ByteArray = "USDC";
        let mut constructor_calldata = array![];
        name.serialize(ref constructor_calldata);
        symbol.serialize(ref constructor_calldata);

        let (contract_address, _) = usdc_contract.deploy(@constructor_calldata).unwrap();
        let usdc_dispatcher = IERC20Dispatcher { contract_address };
        return usdc_dispatcher;
    }

    fn SWIPER_MOCK(USDC_ADDRESS: ContractAddress) -> ISwiperDispatcher {
        let swiper_contract = declare("Swiper").unwrap();
        let mut constructor_calldata = array![USDC_ADDRESS.into()];
        let (contract_address, _) = swiper_contract.deploy(@constructor_calldata).unwrap();
        let swiper_dispatcher = ISwiperDispatcher { contract_address };
        return swiper_dispatcher;
    }

    #[test]
    fn test_swipe() {
        let usdc_dispatcher = USDC_TOKEN_MOCK();
        let usdc_address = usdc_dispatcher.contract_address;
        let swiper_dispatcher = SWIPER_MOCK(usdc_address);
        /// DO NOT MODIFY ANY CODE ABOVE


        //////////////////////////////////////
        ///  YOUR SOLUTION GOES HERE 
        //////////////////////////////////////



        /// DO NOT MODIFY ANY CODE BELOW
        assert!(
            swiper_dispatcher.solved() == true,
            "\n\n\n\n You have not solved this challenge \n\n\n\n"
        );

        print!("\n\n\n\n CHALLENGE COMPLETED SUCCESSFULLY!!! \n\n\n\n")
    }
}
