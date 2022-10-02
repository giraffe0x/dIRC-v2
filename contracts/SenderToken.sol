// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Sender Token
 * @author dIRC Team
 *
 * ERC1155 contract for dIRC Sender Tokens.
*/


interface IReceiverToken {
  function receiverInitialMint(address to, uint tokenId) external;
 }

interface IExternalContract {
  function owner() external view returns (address);
}

contract SenderToken is ERC1155, Ownable {
  /* ========== STATE VARIABLES ========== */
  // NFT name
  string public name;

  // NFT symbol
  string public symbol;

  /* ========== INTERFACES ========== */
  IReceiverToken receiverContract;

  /* ========== EVENTS ========== */
  event SenderMint(address indexed to, uint tokenId, uint amount, uint timestamp);
  event SenderBurn(address indexed from,  uint tokenId, uint amount, uint timestamp);

  /* ========== EXTERNAL MAPPINGS ========== */

  // Mapping from token ID to token existence
  mapping(uint => bool) public exists;

  /* ========== CONSTRUCTOR ========== */
  constructor(string memory _name, string memory _symbol, string memory _uri) ERC1155(_uri) {name = _name; symbol = _symbol;}

  /* ========== MUTATIVE FUNCTIONS ========== */

  // mint function for individual's sender token and trigger receiver token mint
  function senderMint() external {

    string memory addr = Strings.toHexString(uint256(uint160(msg.sender)), 20);
    // hash address into unique token Id
    uint _tokenId = _getTokenId(addr);

    // require keyword not to exist, i.e. it is initial mint
    require (!exists[_tokenId]);

    // mint for sender token and trigger minting of receiver tokens
    _mint(msg.sender, _tokenId, 1, new bytes(0)); // amount set to 1 as individual not expected to require more

    // mint receiver token with identical token id and keyword
    receiverContract.receiverInitialMint(msg.sender, _tokenId);

    // administrative stuff
    exists[_tokenId] = true;

    emit SenderMint(msg.sender, _tokenId, 1, block.timestamp);
  }

  function burn(uint _tokenId, uint _amount) external {
    require((this.balanceOf(msg.sender, _tokenId) > 0), 'must be owner of token');

    _burn(msg.sender, _tokenId, _amount);

    exists[_tokenId] = false;

    emit SenderBurn(msg.sender, _tokenId, _amount, block.timestamp);
  }

  /* ========== VIEW FUNCTIONS ========== */

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
