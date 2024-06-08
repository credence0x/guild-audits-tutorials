# Capture the Flag Challenge: Swiper <br><br>
# Challenge Description

This Capture the Flag (CTF) challenge involves interacting with a starknet smart contract. The system includes two main components: an ERC20 token contract and a Swiper contract. The objective is to exploit the given contracts in order to achieve the `solved` state in the Swiper contract.

## Components
# ERC20 Token Contract (ERC20)

Implements the ERC20 standard functionalities such as transfer, transfer_from, approve, total_supply, and balance_of.
Additional functionality includes a `mint` function that allows minting of tokens to the caller's address.
Note that you can only `mint` `1` single token per call 

# Swiper Contract (Swiper)

This contract is designed to "swipe" a large amount of tokens from a user which implies that the user may need to obtain this large amount in order to complete the challenge. The swipe function checks if the caller has approved the Swiper contract to spend a large amount of tokens and then transfers the required amount from the caller to the Swiper contract's address.
The contract has a solved function that indicates whether the challenge has been completed.

# Objective

The goal of the challenge is to execute the swipe function in the Swiper contract successfully.

## Breakdown
# ERC20 Contract
The ERC20 contract follows the standard ERC20 token specifications with additional minting capabilities. 

# Swiper Contract

The Swiper contract interacts with the ERC20 contract to perform a token swipe operation:

swipe: Transfers a large, predefined amount of tokens (REQUIRED_TOKEN_AMOUNT) from the caller to the Swiper contract's address. This requires the caller to have approved the Swiper contract to spend this amount beforehand.
solved: Returns a boolean indicating whether the challenge has been solved.

# Constants
REQUIRED_TOKEN_AMOUNT: 500,000,000,000 * (10 ** 18) tokens (500 billion tokens with 18 decimal places).


# Solution Testing
The solution should be written in the test section in `challenge.cairo`.<br>
The provided testing framework ensures that the Swiper contract's solved function returns true, indicating the challenge has been completed successfully.


To see if your solution is correct, run `snforge test` from the `ctf` directory