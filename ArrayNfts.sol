// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IERC20 {
    function transfer(address, uint) external;

    function transferFrom(address, address, uint) external;
}

contract ArrayNfts is Ownable, ERC721Enumerable {
    using Address for address;
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public superMinter;
    address public WALLET;
    string public myBaseURI;
    string public myPlatformURI;
    uint public burned;
    bool internal t;

    struct MintFees {
        address usdt;
        uint price;
    }

    MintFees public mintFees;
    struct BurnFees {
        address usdt;
        uint price;
    }
    BurnFees public burnFees;

    struct CardInfo {
        uint cardId;
        uint maxAmount;
        uint currentAmount;
        uint burnedAmount;
        string tokenURI;
    }

    mapping(uint => CardInfo) public cardInfoes;
    mapping(uint => uint) public cardIdMap;
    mapping(address => bool) public superMinters;
    mapping(address => mapping(uint => uint)) public minters;
    mapping(address => bool) public w;
    mapping(uint => address) private cardOwners;

    mapping(uint => uint) public mintedTime;
    mapping(uint => bool) public isBurned;
    mapping(string => string) public cooperationURI;
    // mapping(address => uint) public transferTimes;

    event Mint(address indexed user, uint indexed cardId, uint indexed tokenId);
    event Burn(address indexed user, uint indexed tokenId);
    event Divest(address token, address payee, uint value);
    event NewCard(uint indexed cardId, uint indexed level);

    modifier onlySuperMinters() {
        require(superMinters[msg.sender], "not superMinters!");
        _;
    }

    constructor() ERC721("Arrayit Account Bound Token", "Array") {
        // myBaseURI = myBaseURI_;
        // setBurnFees(, );
        // setMintFees(, );
        // setWALLET();
        setSuperMinter(msg.sender, true);
        cardInfoes[10000] = CardInfo({
            cardId: 10000,
            maxAmount: 10000,
            currentAmount: 0,
            burnedAmount: 0,
            tokenURI: "10000"
        });
        superMinter = msg.sender;
        superMinters[msg.sender] = true;
    }

    // for inherit
    function _burn(uint256 tokenId) internal override(ERC721) {
        ERC721._burn(tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(IERC721, ERC721) {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner nor approved"
        );
        require(t, "0");
        from = to;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(IERC721, ERC721) {
        safeTransferFrom(from, to, tokenId, "");
    }

    // /**
    //  * @dev See {IERC721-safeTransferFrom}.
    //  */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(IERC721, ERC721) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner nor approved"
        );
        require(t, "0");
        from = to;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function setSuperMinter(
        address newSuperMinter_,
        bool b
    ) public onlyOwner returns (bool) {
        superMinters[newSuperMinter_] = b;
        return true;
    }

    function setMinter(
        address newMinter_,
        uint cardId_,
        uint amount_
    ) public onlyOwner returns (bool) {
        minters[newMinter_][cardId_] = amount_;
        return true;
    }

    function setWALLET(address addr_) public onlyOwner {
        WALLET = addr_;
    }

    function setMintFees(address usdt_, uint price_) public onlyOwner {
        mintFees.usdt = usdt_;
        mintFees.price = price_;
    }

    function setBurnFees(address usdt_, uint price_) public onlyOwner {
        burnFees.usdt = usdt_;
        burnFees.price = price_;
    }

    function setMyBaseURI(string calldata uri_) public onlyOwner {
        myBaseURI = uri_;
    }

    function setW(address addr_, bool b_) public onlySuperMinters {
        w[addr_] = b_;
    }

    function setMyPlatformURI(string calldata uri_) public onlySuperMinters {
        myPlatformURI = uri_;
    }

    function setCooperationURI(
        string calldata platform_,
        string calldata uri_
    ) public onlySuperMinters {
        cooperationURI[platform_] = uri_;
    }

    function divest(
        address token_,
        address payee_,
        uint value_
    ) external onlyOwner {
        if (token_ == address(0)) {
            payable(payee_).transfer(value_);
            emit Divest(address(0), payee_, value_);
        } else {
            IERC20(token_).transfer(payee_, value_);
            emit Divest(address(token_), payee_, value_);
        }
    }

    // New Card
    function newCard(
        uint maxAmount_,
        uint cardId_,
        string calldata tokenURI_
    ) public onlyOwner {
        require(
            cardId_ != 0 && cardInfoes[cardId_].cardId == 0,
            "HBT: wrong cardId"
        );

        cardInfoes[cardId_] = CardInfo({
            cardId: cardId_,
            maxAmount: maxAmount_,
            currentAmount: 0,
            burnedAmount: 0,
            tokenURI: tokenURI_
        });
        emit NewCard(cardId_, maxAmount_);
    }

    // edit Card
    function editCard(
        uint maxAmount_,
        uint cardId_,
        string calldata tokenURI_
    ) public onlyOwner {
        require(
            cardId_ != 0 && cardInfoes[cardId_].cardId == cardId_,
            "HBT: wrong cardId"
        );

        cardInfoes[cardId_] = CardInfo({
            cardId: cardId_,
            maxAmount: maxAmount_,
            currentAmount: cardInfoes[cardId_].currentAmount,
            burnedAmount: cardInfoes[cardId_].burnedAmount,
            tokenURI: tokenURI_
        });
    }

    function getNowTokenId() public view returns (uint) {
        return _tokenIds.current();
    }

    // get Next TokenId
    function getNextTokenId() internal returns (uint) {
        _tokenIds.increment();
        uint ids = _tokenIds.current();
        return ids;
    }

    // mint
    function mint(uint cardId_) public returns (uint) {
        require(
            cardInfoes[cardId_].currentAmount < cardInfoes[cardId_].maxAmount,
            "out of max"
        );
        require(balanceOf(msg.sender) == 0, "Already have a HBT");
        require(
            cardId_ != 0 && cardInfoes[cardId_].cardId != 0,
            "HBT: wrong cardId"
        );
        if (mintFees.usdt != address(0) && mintFees.price > 0) {
            if (!w[msg.sender]) {
                IERC20(mintFees.usdt).transferFrom(
                    msg.sender,
                    WALLET,
                    mintFees.price
                );
            }
        }

        cardInfoes[cardId_].currentAmount += 1;

        uint tokenId = getNextTokenId();
        cardIdMap[tokenId] = cardId_;
        mintedTime[tokenId] = block.timestamp;
        cardOwners[tokenId] = msg.sender;
        _safeMint(msg.sender, tokenId);

        emit Mint(msg.sender, cardId_, tokenId);
        return tokenId;
    }

    function mintFromMinters(
        address player_,
        uint cardId_
    ) public returns (uint) {
        require(
            cardInfoes[cardId_].currentAmount < cardInfoes[cardId_].maxAmount,
            "out of max"
        );
        require(balanceOf(player_) == 0, "Already have a HBT");
        require(
            cardId_ != 0 && cardInfoes[cardId_].cardId != 0,
            "HBT: wrong cardId"
        );

        if (superMinter != _msgSender() && !superMinters[_msgSender()]) {
            require(minters[_msgSender()][cardId_] > 0, "HBT: not minter");
            minters[_msgSender()][cardId_] -= 1;
        }

        cardInfoes[cardId_].currentAmount += 1;

        uint tokenId = getNextTokenId();
        cardIdMap[tokenId] = cardId_;
        mintedTime[tokenId] = block.timestamp;
        cardOwners[tokenId] = player_;
        _safeMint(player_, tokenId);

        emit Mint(player_, cardId_, tokenId);
        return tokenId;
    }

    // mint Batch 2
    function mintFromMintersMulti(
        address[] calldata player_,
        uint cardId_
    ) public returns (bool) {
        if (superMinter != _msgSender() && !superMinters[_msgSender()]) {
            require(minters[_msgSender()][cardId_] > 0, "HBT: not minter");
            minters[_msgSender()][cardId_] -= 1;
        }
        require(player_.length > 0, "length mismatch");
        uint ba;
        for (uint i = 0; i < player_.length; ++i) {
            ba = balanceOf(player_[i]);
            if (ba == 0) {
                mintFromMinters(player_[i], cardId_);
            }
        }
        return true;
    }

    // burn
    function burn(uint tokenId_) public returns (bool) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId_),
            "HBT: burner isn't owner"
        );

        if (burnFees.usdt != address(0) && burnFees.price > 0) {
            if (!w[msg.sender]) {
                IERC20(burnFees.usdt).transferFrom(
                    msg.sender,
                    WALLET,
                    burnFees.price
                );
            }
        }

        uint cardId = cardIdMap[tokenId_];
        cardInfoes[cardId].currentAmount -= 1;
        cardInfoes[cardId].burnedAmount += 1;
        isBurned[tokenId_] = true;
        burned += 1;

        _burn(tokenId_);
        emit Burn(msg.sender, tokenId_);
        return true;
    }

    function burnFromMinter(
        address user_,
        uint tokenId_
    ) public onlySuperMinters returns (bool) {
        require(user_ == ownerOf(tokenId_), "user_ is not nft owner");
        uint cardId = cardIdMap[tokenId_];
        cardInfoes[cardId].currentAmount -= 1;
        cardInfoes[cardId].burnedAmount += 1;
        isBurned[tokenId_] = true;
        burned += 1;

        _burn(tokenId_);
        emit Burn(user_, tokenId_);
        return true;
    }

    function exists(uint tokenId_) public view returns (bool) {
        return _exists(tokenId_);
    }

    // check this tokenid's tokenURIs
    function tokenURI(
        uint tokenId_
    ) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId_), "HBT: nonexistent token");

        return
            string(
                abi.encodePacked(
                    _myBaseURI(),
                    "/",
                    cardInfoes[cardIdMap[tokenId_]].tokenURI
                )
            );
    }

    // check this address all tokenURIs
    function playerTokenURI(
        address account_
    ) public view returns (string[] memory) {
        uint amount = balanceOf(account_);
        uint tokenId;
        string[] memory info = new string[](amount);
        for (uint i = 0; i < amount; i++) {
            tokenId = tokenOfOwnerByIndex(account_, i);
            info[i] = tokenURI(tokenId);
        }
        return info;
    }

    // check baseURI
    function _myBaseURI() internal view returns (string memory) {
        return myBaseURI;
    }

    function tokenOfOwnerForAll(
        address addr_
    ) public view returns (uint[] memory, uint[] memory) {
        uint len = balanceOf(addr_);
        uint id;
        uint[] memory _TokenIds = new uint[](len);
        uint[] memory _CardIds = new uint[](len);
        for (uint i = 0; i < len; i++) {
            id = tokenOfOwnerByIndex(addr_, i);
            _TokenIds[i] = id;
            _CardIds[i] = cardIdMap[id];
        }
        return (_TokenIds, _CardIds);
    }

    function _platformURI() internal view returns (string memory) {
        return myPlatformURI;
    }

    function _cooperationURI(
        string calldata s_
    ) internal view returns (string memory) {
        return cooperationURI[s_];
    }

    function tokenPlatformURI(
        uint tokenId_
    ) public view returns (string memory) {
        require(_exists(tokenId_), "HBT: nonexistent token");
        return
            string(abi.encodePacked(_platformURI(), "/", tokenId_.toString()));
    }

    function checkCooperationURI(
        string calldata s_
    ) public view returns (string memory) {
        return _cooperationURI(s_);
    }

    function checkCardStatus(
        uint tokenId_
    )
        public
        view
        returns (
            bool _isMinted,
            bool _isBurned,
            address _holder,
            uint _mintedTime
        )
    {
        _isMinted = _exists(tokenId_);
        _isBurned = isBurned[tokenId_];
        _holder = cardOwners[tokenId_];
        _mintedTime = mintedTime[tokenId_];
    }
}
