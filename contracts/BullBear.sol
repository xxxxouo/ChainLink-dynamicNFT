// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// Chainlink Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


//  deploy: goerli 0x4b5Dac5Ee4611BfB2915E5e04286f422DfE6458e
contract BullBear is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, KeeperCompatibleInterface,VRFConsumerBaseV2 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    // address public owner;

    AggregatorV3Interface public priceFeed;
    //VRF
    VRFCoordinatorV2Interface public COORDINATOR;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint32 public callbackGasLimit = 500000; // set higher as fulfillRandomWords is doing a LOT of heavy lifting.
    uint64 public s_subscriptionId;
    bytes32 keyhash =  0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15; 

    enum MarketTrend{
      BULL,
      BEAR
    }
    MarketTrend public currentMarketTrend = MarketTrend.BULL;


    uint256 public /*immutable*/ interval;
    uint256 public lastTimeStamp;
    int256 public currentPrice;

    string[] bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];
    string[] bearUrisIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    event TokensUpdated(string marketTrend);

    constructor(uint256 updateInterval, address _priceFeed, address _vrfCoordinator) ERC721("Bull&Bear", "BBTK")VRFConsumerBaseV2(_vrfCoordinator) {
        // owner = msg.sender;
        // 设置了keeper 更新间隔数据 
        interval = updateInterval;
        lastTimeStamp = block.timestamp;
        
        //  获取价格信息 
        // BTC/USD Price Feed Contract Address on Goerli: https://goerli.etherscan.io/address/0xA39434A63A52E749F02807ae27335515BA4b07F7
        // or the MockPriceFeed Contract
        priceFeed = AggregatorV3Interface(_priceFeed);

        currentPrice = getLatestPrice();
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        // 设置mint 默认公牛图像
        string memory defaultURI = bullUrisIpfs[0];
        _setTokenURI(tokenId, defaultURI);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            int256 latestPrice = getLatestPrice();

            if( latestPrice == currentPrice ){
              return;
            }

            if(latestPrice < currentPrice){
                currentMarketTrend = MarketTrend.BEAR;
            } else {
                currentMarketTrend = MarketTrend.BULL;
            }
            // 启动VRF获取随机数字
            requestRandomnessForNFTUris();
            currentPrice = latestPrice;
        }
    }

    function getLatestPrice() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return answer;
    }

    function requestRandomnessForNFTUris() internal {
      require(s_subscriptionId != 0 ,"Subscription ID not set");
      s_requestId = COORDINATOR.requestRandomWords(
        keyhash,
        s_subscriptionId,
        3,
        callbackGasLimit,
        1
      );
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory randomWords) internal override {
      s_randomWords = randomWords;
      string[] memory urisForTrend = currentMarketTrend == MarketTrend.BULL? bullUrisIpfs: bearUrisIpfs;
      uint idx = s_randomWords[0] % urisForTrend.length;
      for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
        _setTokenURI(i, urisForTrend[idx]);
      }
      string memory trend = currentMarketTrend == MarketTrend.BULL ? "bullish" : "bearish";
      emit TokensUpdated(trend);
    }


    //Helps
    function compareStrings(string memory a, string memory b) private pure returns(bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }

    // modifier onlyOwner() {
    //     require(msg.sender == owner,"go out, you can't set it");
    // }

    function setInterval(uint256 newInterval) public onlyOwner {
        interval = newInterval;
    }

    function setPriceFeed(address newPriceFeed) public onlyOwner {
        priceFeed = AggregatorV3Interface(newPriceFeed);
    }
    // For VRF Subscription Manager
    function setSubscriptionId(uint64 _id) public onlyOwner {
        s_subscriptionId = _id;
    }
    function setCallbackGasLimit(uint32 maxGas) public onlyOwner {
      callbackGasLimit = maxGas;
    }
    function setVrfCoodinator(address _address) public onlyOwner {
      COORDINATOR = VRFCoordinatorV2Interface(_address);
  } 

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}