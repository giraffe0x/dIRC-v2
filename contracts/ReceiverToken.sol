// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title Receiver Token
 * @author dIRC Team
 *
 * ERC1155 contract for dIRC Receiver Tokens.
*/

interface IExternalERC721Contract {
  function balanceOf(address owner) external view returns (uint);
}

interface IExternalERC1155Contract {
  function balanceOf(address owner, uint tokenId) external view returns (uint);
}

interface IChannelContract {
  struct Token {
    uint _supply;
    string _name; // channel name
    string _description; // channel description
    bool _gated; // is the channel token gated?
    uint _chainId; // which chain is the token-gated contract on?
    bool _isErc1155; // is token-gated contract ERC1155?
    uint _minHolding; // what is the minimum holding of token to pass thru token gate
    address _gated_contract; // address on token-gated contract
    bool _reply_allowed; // are messages by non-admins allowed?
    address _owner;
  }

  function getChannelToken(uint _id) external view returns (Token memory token);
}

contract ReceiverToken is ERC1155, Ownable {
  /* ========== STATE VARIABLES ========== */
    // NFT name
  string public name;

  // NFT symbol
  string public symbol;

  // Contract for Sender token minter
  address public senderContractAddress;

  // Contract for channel token minter
  address public channelContractAddress;

  // sender token struct
  IChannelContract.Token channelToken;

  /* ========== INTERFACES ========== */
  IChannelContract channelContract;

  IExternalERC721Contract externalERC721Contract;

  IExternalERC1155Contract externalERC1155Contract;

  /* ========== MODIFIERS ========== */
  modifier onlySenderorChannelContract {
      require((msg.sender == senderContractAddress) || (msg.sender == channelContractAddress), "caller is not SenderContract");
      _;
  }

  /* ========== EVENTS ========== */
  event ReceiverMint(address indexed to, uint tokenId, uint amount, uint timestamp);
  event ReceiverChannelMint(address indexed to, uint tokenId, uint amount, uint timestamp);
  event RelayedReceiverMint(address indexed to, uint tokenId, uint amount, uint chainId, uint timestamp);
  event ReceiverBatchMint(address indexed to, uint[] tokenIds, uint[] amounts, uint timestamp);
  event ReceiverBurn(address indexed from,  uint tokenId, uint amount, uint timestamp);
  event ReceiverTransfer(address indexed from, address to, uint id, uint amount, uint timestamp);
  event ReceiverBatchTransfer(address indexed from, address to, uint256[] ids, uint256[] amounts, uint timestamp);

  /* ========== EXTERNAL MAPPINGS ========== */
  // Mapping from token ID to token supply
  mapping(uint => uint) public tokenSupply;

  // Mapping from id to token existence
  mapping(uint => bool) public _exists;

  // Mapping from id to channel token type
  mapping(uint=> bool) public _isChannel;

  /* ========== CONSTANTS ========== */

  /* ========== STRUCTS ========== */

  /* ========== CONSTRUCTOR ========== */
  constructor(string memory _name, string memory _symbol, string memory _uri) ERC1155(_uri) {name = _name; symbol = _symbol;}

  /* ========== EXTERNAL FUNCTIONS ========== */

  function receiverMint(uint _tokenId) external {
    require(_exists[_tokenId], "token does not exist, mint sender token first");
    require(!_isChannel[_tokenId], "token is a channel token");

    _mint(msg.sender, _tokenId, 1, new bytes(0));
    emit ReceiverMint(msg.sender, _tokenId, 1, block.timestamp);

    tokenSupply[_tokenId] = tokenSupply[_tokenId] + 1;
  }

  function receiverChannelMint(uint _tokenId) external {
    require(_exists[_tokenId], "token does not exist, mint sender token first");
    require(_isChannel[_tokenId], "token is not a channel token");

    channelContract = IChannelContract(channelContractAddress);

    channelToken = channelContract.getChannelToken(_tokenId);

    // if not token gated, allow mint
    if (!channelToken._gated) {
      _mint(msg.sender, _tokenId, 1, new bytes(0));
      emit ReceiverChannelMint(msg.sender, _tokenId, 1, block.timestamp);
    }

    // if token gated on Arbitrum, check if msg.sender holds the required token/nft
    if (channelToken._gated && channelToken._chainId == 10010) {

      if (!channelToken._isErc1155) {
        externalERC721Contract = IExternalERC721Contract(channelToken._gated_contract);

        require(externalERC721Contract.balanceOf(msg.sender) >= channelToken._minHolding, "need to hold required bal of token/nft");

        _mint(msg.sender, _tokenId, 1, new bytes(0));
      }
      if (channelToken._isErc1155) {
        externalERC1155Contract = IExternalERC1155Contract(channelToken._gated_contract);

        require(externalERC1155Contract.balanceOf(msg.sender, _tokenId) >= channelToken._minHolding, "need to hold required bal of token/nft");

        _mint(msg.sender, _tokenId, 1, new bytes(0));
      }

      emit ReceiverChannelMint(msg.sender, _tokenId, 1, block.timestamp);
    }
  }

  function mintBatchReceiver(uint[] memory ids, uint[] memory amounts) external {
    uint[] memory idExists = new uint[](ids.length);
    uint counter = 0;
    for (uint i=0; i < ids.length; i++) {
      if(_exists[ids[i]]) {
        idExists[counter]= ids[i];
        counter++;
      }
    }
    require(idExists.length == amounts.length, "Mismatched array lengths or some tokenIds do not exist");

    _mintBatch(msg.sender, idExists, amounts, new bytes(0));

    for (uint i=0; i<idExists.length; i++) {
      tokenSupply[ids[i]] = tokenSupply[ids[i]] + amounts[i];
    }

    emit ReceiverBatchMint(msg.sender, idExists, amounts, block.timestamp);
  }

  function burn(address from, uint tokenId, uint amount) external {
    require((msg.sender == from || msg.sender == owner()), "must be owner of token");

    _burn(from, tokenId, amount);
    tokenSupply[tokenId] - amount;

    emit ReceiverBurn(from, tokenId, amount, block.timestamp);
  }

  /* ========== VIEW FUNCTIONS ========== */

  /* ========== INTERNAL FUNCTIONS ========== */

  /* ========== RESTRICTED  FUNCTIONS ========== */

  // called only by sender contract when minting a fresh sender token
  function receiverInitialMint(address to, uint tokenId) external onlySenderorChannelContract {

    _mint(to, tokenId, 1, new bytes(0));

    tokenSupply[tokenId] = tokenSupply[tokenId] + 1;
    _exists[tokenId] = true;

    emit ReceiverMint(to, tokenId, 1, block.timestamp);
  }

  // called only by channel token contract when minting a fresh channel token
  function _receiverChannelInitialMint(address _to, uint _tokenId, address[] memory admins) external onlySenderorChannelContract {

    _mint(_to, _tokenId, 1, new bytes(0));

    // mint to all admins
    uint i = 0;
      for (i = 0; i<admins.length; i++) {
        _mint(admins[i], _tokenId, 1, new bytes(0));
    }

    // admin stuff
    _exists[_tokenId] = true;
    _isChannel[_tokenId] = true;

    emit ReceiverChannelMint(_to, _tokenId, 1, block.timestamp);
  }

  function _receiverChannelMint(address _to, uint _tokenId) external onlySenderorChannelContract {

    _mint(_to, _tokenId, 1, new bytes(0));

    emit ReceiverChannelMint(_to, _tokenId, 1, block.timestamp);
  }

  // function relayedMintReceiverChannel(address _to, uint _tokenId, uint _amount) external onlyRelayedContract {

  // }

  function setSenderContractAddress(address _contract) external onlyOwner {
    senderContractAddress = _contract;
  }

  function setChannelContractAddress(address _contract) external onlyOwner {
    channelContractAddress = _contract;
  }

  // making the tokens soulbound
  function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override virtual {
    require(from == address(0)|| to == address(0), "token cant be transferred");
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }
}
