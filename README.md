# Proveably Random Raffle Contracts

## About

This code creates a proveably random smart contract lottery

## How does it work?

1. Users can enter by paying for a ticket
   1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
   1. And this will be done programmatically
3. Using Chainling VRF & Chainlink Automation
   1. Chainlink VRF -> Randomness
   2. Chainlink Automation -> Time based trigger
