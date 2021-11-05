// SPDX_License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract RandomSVG is ERC721URIStorage, VRFConsumerBase {

    bytes32 public keyHash;
    uint256 public fee;
    uint256 public tokenCounter;

    //SVG Parameters
    uint256 public maxNumberOfPaths;
    uint256 public maxNumberOfPathCommands;
    uint256 public size;
    string[] public pathCommands;
    string[] public colors;

    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => uint256) public requestIdToTokenId;
    mapping(uint256 => uint256) public tokenIdToRandomNumber;

    event requestedRandomSVG(bytes32 indexed requestId, uint256 indexed tokenId);
    event CreatedUnfinishedRandomSVG(uint256 indexed tokenId, uint256 randomNumber);
    event CreatedRandomSVG(uint256 indexed tokenId, string tokenURI);

    constructor(address _VRFCoordinator, address _LinkToken, bytes32 _keyHash, uint256 _fee) 
        VRFConsumerBase(_VRFCoordinator, _LinkToken) 
        ERC721 ("RandomSVG", "rsNFT"){

            fee = _fee;
            keyHash = _keyHash;
            tokenCounter = 0;

            maxNumberOfPaths = 10;
            maxNumberOfPathCommands = 5;
            size = 500;
            pathCommands = ["M", "L"];
            colors = ["red", "blue", "green", "yellow", "black", "white"];
        
    }

    function create() public returns (bytes32 requestId) {
        // get a random number, use it to generate random SVG code
        requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = msg.sender;

        uint256 tokenId = tokenCounter;

        requestIdToTokenId[requestId] = tokenId;

        tokenCounter = tokenCounter + 1;

        emit requestedRandomSVG(requestId, tokenId);
        
        // base64 encode SVG code
        // get tokenURI and mint the NFT
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber) internal override {
        // Issue: Chainlink VRF max gas = 200k gas (computation units)
        // 2M gas -- heavy lifting on chain
        address nftOwner = requestIdToSender[requestId];
        uint256 tokenId = requestIdToTokenId[requestId];
        _safeMint(nftOwner, tokenId);
        //generateRandomSVG
        tokenIdToRandomNumber[tokenId] = randomNumber;
        emit CreatedUnfinishedRandomSVG(tokenId, randomNumber);
    }

    function finishMint(uint256 tokenId) public {

        //check to see if it's been minted and a random number is returned
        require(bytes(tokenURI(tokenId)).length <= 0, "tokenURI is already all set!");
        require(tokenCounter > tokenId, "tokenId has not been minted yet!");
        require(tokenIdToRandomNumber[tokenId] > 0, "Need to wait for Chainlink VRF");
        uint256 randomNumber = tokenIdToRandomNumber[tokenId];

        //generate some random SVG code
        string memory svg = generateSVG(randomNumber);
        //turn that into an image URI
        string memory imageURI = svgToImageURI(svg);
        //use that imageURI to format into a tokenURI
        string memory tokenURI = formatTokenURI(imageURI);

        _setTokenURI(tokenId, tokenURI);
        emit CreatedRandomSVG(tokenId, svg);
    }

    function generateSVG(uint256 _randomNumber) public view returns (string memory finalSVG){
        uint256 numberOfPaths = (_randomNumber % maxNumberOfPaths) + 1;
        finalSVG = string(abi.encodePacked("<svg xmlns='http://www.w3.org/2000/svg' height='", uint2str(size), "' width='", uint2str(size), "'>"));
        for (uint i = 0; i < numberOfPaths; i++){
            uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, i)));
            string memory pathSVG = generatePath(newRNG);
            finalSVG = string(abi.encodePacked(finalSVG, pathSVG));
        }
        finalSVG = string(abi.encodePacked(finalSVG, "</svg>"));
    }

    function generatePath(uint256 _randomNumber) public view returns (string memory pathSVG){
        uint256 numberOfPathCommands = (_randomNumber % maxNumberOfPathCommands) + 1;
        pathSVG = "<path d='";
        for (uint i = 0; i < numberOfPathCommands; i++){
            uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, size + i)));
            string memory pathCommand = generatePathCommand(newRNG);
            pathSVG = string(abi.encodePacked(pathSVG, pathCommand));
        }
        string memory color = colors[_randomNumber % colors.length];
        pathSVG = string(abi.encodePacked(pathSVG, "' fill='transparent' stroke='", color, "'/>"));
    }

    function generatePathCommand(uint256 _randomNumber) public view returns (string memory pathCommand){
        pathCommand = pathCommands[_randomNumber % pathCommands.length];
        uint256 firstParam = uint256(keccak256(abi.encode(_randomNumber, size * 2))) % size;
        uint256 secondParam = uint256(keccak256(abi.encode(_randomNumber, size * 3))) % size;
        pathCommand = string(abi.encodePacked(pathCommand, " ", uint2str(firstParam), " ", uint2str(secondParam)));
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function svgToImageURI(string memory svg) public pure returns (string memory){
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        string memory imageURI = string(abi.encodePacked(baseURL, svgBase64Encoded));
        return imageURI;
    }

    function formatTokenURI(string memory imageURI) public pure returns (string memory){
        string memory baseURL = "data:application/json;base64,";
        return string(abi.encodePacked(baseURL,Base64.encode(bytes(abi.encodePacked('{"name": "SVG NFT", "description": "An NFT based on SVG!", "attributes": "", "image": "', imageURI, '"}')))));
    }
}