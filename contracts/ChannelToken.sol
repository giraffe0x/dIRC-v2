// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Channel Token
 * @author dIRC Team
 *
 * ERC1155 contract for dIRC Channel Tokens.
*/


interface IReceiverToken {
  function _receiverChannelInitialMint(address to, uint tokenId, address[] memory admins) external;

  function _receiverChannelMint(address to, uint tokenId) external;
 }

 interface IExternalERC721Contract {
  function balanceOf(address owner) external view returns (uint);
}

interface IExternalERC1155Contract {
  function balanceOf(address owner, uint tokenId) external view returns (uint);
}

contract ChannelToken is ERC1155, Ownable {
  /* ========== STATE VARIABLES ========== */
  // NFT name
  string public name;

  // NFT symbol
  string public symbol;

  uint256 nextTokenId = 1000;

  /* ========== INTERFACES ========== */
  IReceiverToken receiverContract;

  IExternalERC721Contract externalERC721Contract;

  IExternalERC1155Contract externalERC1155Contract;

  /* ========== EVENTS ========== */
  event ChannelInitialMint(address indexed to, uint tokenId, string name, string desc, bool gated, uint chainId, bool _isErc1155, uint _minHolding, address gated_contract, bool onlyAdminsTalk, address[] admins, address owner, uint timestamp);
  event ChannelGatedMint(address indexed to, uint tokenId);
  event ChannelBurn(address indexed from, uint tokenId, uint amount, uint timestamp);

  /* ========== STRUCTS ========== */
  struct Token {
    uint _supply;
    string _name; // channel name
    string _description; // channel description
    bool _gated; // is the channel token gated?
    uint _chainId; // which chain is the token-gated contract on?
    bool _isErc1155; // is token-gated contract ERC1155?
    uint _minHolding; // what is the minimum holding of token to pass thru token gate
    address _gated_contract; // address on token-gated contract
    bool _onlyAdminsTalk; // are messages by non-admins allowed?
    address[] admins;
    address _owner;
  }

  /* ========== EXTERNAL MAPPINGS ========== */

  // Mapping from token ID to token struct
  mapping(uint => Token) public tokens;

  /* ========== CONSTRUCTOR ========== */
  constructor(string memory _name, string memory _symbol, string memory _uri) ERC1155(_uri) {name = _name; symbol = _symbol;}

  /* ========== MUTATIVE FUNCTIONS ========== */

  // mint function for channel token and trigger receiver token mint
  function channelInitialMint(string memory _name, string memory _desc, bool _gated, uint _chainId, bool _isErc1155, uint _minHolding, address _gated_contract, bool _onlyAdminsTalk, address[] memory admins) external {
    uint _tokenId = ++nextTokenId;

    // mint for sender token and trigger minting of receiver tokens
    _mint(msg.sender, _tokenId, 1, new bytes(0)); // amount to mint set to 1

    // mint receiver token with identical token id and keyword
    receiverContract._receiverChannelInitialMint(msg.sender, _tokenId, admins);

    // mint to all admins
    uint i = 0;
      for (i = 0; i<admins.length; i++) {
        _mint(admins[i], _tokenId, 1, new bytes(0));
    }

    // administrative stuff
    tokens[_tokenId] = Token(1, _name, _desc, _gated, _chainId, _isErc1155, _minHolding, _gated_contract, _onlyAdminsTalk, admins, msg.sender);

    emit ChannelInitialMint(msg.sender, _tokenId, _name, _desc, _gated, _chainId, _isErc1155, _minHolding, _gated_contract, _onlyAdminsTalk, admins, msg.sender, block.timestamp);
  }

  // if channel is gated & non-admins can talk
  function channelGatedMint(uint _tokenId) external {
    Token memory token = tokens[_tokenId];

    if (!token._isErc1155) {
        externalERC721Contract = IExternalERC721Contract(token._gated_contract);

        require(externalERC721Contract.balanceOf(msg.sender) >= token._minHolding, "need to hold required bal of token/nft");

        _mint(msg.sender, _tokenId, 1, new bytes(0));
      }
    if (token._isErc1155) {
      externalERC1155Contract = IExternalERC1155Contract(token._gated_contract);

      require(externalERC1155Contract.balanceOf(msg.sender, _tokenId) >= token._minHolding, "need to hold required bal of token/nft");

      _mint(msg.sender, _tokenId, 1, new bytes(0));
    }

    receiverContract._receiverChannelMint(msg.sender, _tokenId);

    emit ChannelGatedMint(msg.sender, _tokenId);
  }

  function channelMint(uint _tokenId) external {
    Token memory token = tokens[_tokenId];
    require(!token._gated, "token is gated");

    _mint(msg.sender, _tokenId, 1, new bytes(0));
    receiverContract._receiverChannelMint(msg.sender, _tokenId);
  }

  function burn(uint _tokenId, uint _amount) external {
    require((this.balanceOf(msg.sender, _tokenId) > 0), 'must be owner of token');

    _burn(msg.sender, _tokenId, _amount);

    emit ChannelBurn(msg.sender, _tokenId, _amount, block.timestamp);
  }

  /* ========== VIEW FUNCTIONS ========== */
  function getChannelToken(uint id) external view returns (Token memory token) {
    return tokens[id];
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function _getTokenId(string memory _keyword) internal pure returns (uint) {
    uint hashDigits = 8;
    uint hashModulus = 10 ** hashDigits;

    uint tokenId = uint(keccak256(abi.encodePacked(_keyword)));

    return tokenId % hashModulus;
  }

  /* ========== RESTRICTED  FUNCTIONS ========== */

  // set address of receiverToken contract
  function setReceiverContractAddress(address _address) external onlyOwner {
    receiverContract = IReceiverToken(_address);
  }

  // making the sender tokens soulbound
  function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override virtual {
    require(from == address(0)|| to == address(0), "token cant be transferred");
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }
}
