

/// This is a sample code that shows that low level calls
/// may be used to modify `read only` functions
/// 

#[starknet::interface]
trait ISample<TContractState> {
    fn do_nothing(self: @TContractState);
    fn set_name(ref self: TContractState, name: felt252);
    fn read_name(self: @TContractState) -> felt252;
}


#[starknet::contract]
mod sample {
    use core::result::ResultTrait;
    use starknet::contract_address_const;

    #[storage]
    struct Storage {
        name: felt252
    }

    #[abi(embed_v0)]    
    impl SampleImpl of super::ISample<ContractState> {
        fn do_nothing(self: @ContractState) {

            let addr = starknet::get_contract_address();
            let selector = selector!("set_name");

            let mut calldata: Array<felt252> = array![];
            let name = 'shade';
            name.serialize(ref calldata);

            let _ 
                = starknet::syscalls::call_contract_syscall(addr, selector, calldata.span()).unwrap();      
        }

        fn set_name(ref self: ContractState, name: felt252) {
            self.name.write(name);      
        }

        fn read_name(self: @ContractState) -> felt252 {
            self.name.read()
        }
    }
}



#[cfg(test)]
mod test {
    use super::{ISample, ISampleDispatcher, ISampleDispatcherTrait, sample};
    use snforge_std::{
        declare, ContractClassTrait, spy_events, SpyOn, EventSpy, EventAssertions, test_address,
        start_roll, stop_roll, start_warp, stop_warp, CheatTarget, start_prank, stop_prank
    };


    fn SAMPLE_MOCK() -> ISampleDispatcher {
        let sample_contract = declare("sample").unwrap();
        let (contract_address, _) = sample_contract.deploy(@array![]).unwrap();
        let dispatcher = ISampleDispatcher { contract_address };
        return dispatcher;
    }

    #[test]
    fn test_sample_name() {
        let sample = SAMPLE_MOCK();
        assert_eq!(sample.read_name(), '');

        // this should do nothing
        sample.do_nothing();

        // but it changes the state of the contract
        assert_eq!(sample.read_name(), 'shade');
    }

}
