use starknet::ContractAddress;

#[starknet::interface]
trait IERC20Mint<TState> {
    /// Allows the caller mint 1 token at a time
    fn mint(ref self: TState);
}

#[starknet::interface]
trait IERC20<TState> {
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
mod ERC20 {
    use integer::BoundedInt;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC20_name: felt252,
        ERC20_symbol: felt252,
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
    impl ERC20Impl of super::IERC20<ContractState> {
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

    #[generate_trait]
    #[abi(per_item)]
    impl ERC20MetadataImpl of IERC20Metadata {
        /// Returns the name of the token.
        #[external(v0)]
        fn name(self: @ContractState) -> felt252 {
            self.ERC20_name.read()
        }

        /// Returns the ticker symbol of the token, usually a shorter version of the name.
        #[external(v0)]
        fn symbol(self: @ContractState) -> felt252 {
            self.ERC20_symbol.read()
        }

        /// Returns the number of decimals used to get its user representation.
        fn decimals(self: @ContractState) -> u8 {
            18
        }
    }

    #[abi(embed_v0)]
    impl ERC20MintImpl of super::IERC20Mint<ContractState> {
        fn mint(ref self: ContractState) {
            self._mint(starknet::get_caller_address(), 1)
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, symbol: felt252) {
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


#[starknet::contract]
mod Prize {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::ERC20HooksEmptyImpl;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer("CTF PRIZE", "PURR");
        self.ownable.initializer(owner);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl PrizelImpl of PrizeTrait {
        #[external(v0)]
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20._mint(recipient, amount);
        }
    }
}
