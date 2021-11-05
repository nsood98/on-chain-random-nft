# Basic SVG NFT Project

Basic SVG NFT (Random and Non-Random) use case. Contract creates and deploys to Hardhat or Rinkeby testnet.

Uses Chainlink VRF for randomness.

Contains two contracts and deployment scripts.

```shell
npx hardhat compile
npx hardhat help
```
Deploy locally (regular svg and random, respectively):
```shell
npx hardhat deploy --tags svg
npx hardhat deploy --tags rsvg
```
add `network --rinkeby` for Rinkeby deployment (must have Rinkeby ETH and Chainlink tokens to deploy)
