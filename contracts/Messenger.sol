// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IReceiverToken {
  function balanceOf(address _owner, uint _tokenId) external returns(uint);
 }

 interface ISenderToken {
  function balanceOf(address _owner, uint _tokenId) external returns(uint);
 }

 interface IChannelToken {
  function balanceOf(address _owner, uint _tokenId) external returns(uint);
 }

contract Messenger is Ownable {

  event NewChannelMessage(address indexed from, uint senderTokenId, uint channelTokenId, uint timestamp, string message);
  // event NewRelayedMessage(address indexed from, uint srcChainId, uint tokenId, uint timestamp, string message);
  // event NewReply(address indexed from, string messageId, uint timestamp, string message);
  // event NewRelayedReply(address indexed from, uint srcChainId, string messageId, uint timestamp, string message);

  // uint replyMessagePrice = 1000000000000000; // 0.001 eth
  uint replyMessagePrice = 0; // free just pay gas

  IReceiverToken receiverContract;
  ISenderToken senderContract;
  IChannelToken channelContract;

  /* ========== MUTATIVE FUNCTIONS ========== */

  // sending a message from base chain
  function sendChannelMessage(uint _senderTokenId, uint _channelTokenId, string calldata _content) public {
    // require sender to hold sender token first
    require ((senderContract.balanceOf(msg.sender, _senderTokenId) > 0 && channelContract.balanceOf(msg.sender, _channelTokenId) > 0), "Error: must hold correct sender/channel token");

    emit NewChannelMessage(msg.sender, _senderTokenId, _channelTokenId, block.timestamp, _content);
  }

  // sending a message from another chain/network
  // // function sendRelayedMessage(address _from, uint _srcChainId, uint _tokenId, string calldata _content) public {
  // //   // require sender to hold sender NFT first
  // //   require ((relayerContract.balanceOf(_from, _tokenId) > 0), "Error: must hold reciprocal Sender NFT!");

  // //   emit NewRelayedMessage(_from, _srcChainId, _tokenId, block.timestamp, _content);
  // // }

  // // sending a reply from base chain
  // // function replyMessage(string memory _messageId, string calldata _content) public payable {
  // //   require ((msg.value >= replyMessagePrice), "not enought eth sent");

  // //   emit NewReply(msg.sender, _messageId, block.timestamp, _content);
  // }

  // sending a reply from another chain/network
  // function sendRelayedReply(address _from, uint _srcChainId, string memory _messageId, string calldata _content) public payable {
  //   require ((msg.value >= replyMessagePrice), "not enought eth sent");

  //   emit NewRelayedReply(_from, _srcChainId, _messageId, block.timestamp, _content);
  // }

  /* ========== RESTRICTED  FUNCTIONS ========== */

  function setReceiverContractAddress(address _address) external onlyOwner {
    receiverContract = IReceiverToken(_address);
  }

  function setSenderContractAddress(address _address) external onlyOwner {
    senderContract = ISenderToken(_address);
  }

  function setChannelContractAddress(address _address) external onlyOwner {
    channelContract = IChannelToken(_address);
  }

  // function setReplyMessagePrice(uint _price) external onlyOwner {
  //   replyMessagePrice = _price;
  // }

  function withdraw() public payable onlyOwner {
    (bool os,)= payable(owner()).call{value:address(this).balance}("");
    require(os);
  }
}
