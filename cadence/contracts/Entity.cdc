import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"

pub contract Entity: NonFungibleToken {

  pub var totalSupply: UInt64

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)

  pub event GeneratorCreated()
  pub event ElementGenerateSuccess(hex: String)
  pub event ElementGenerateFailure(hex: String)
  pub event ElementDeposit(hex: String)
  pub event CollectionCreated()

  // 元特征
  pub struct MetaFeature {

    pub let bytes: [UInt8]
    pub let raw: String?

    init(bytes: [UInt8], raw: String?) {
      self.bytes = bytes
      self.raw = raw
    }
  }

  // 元要素
  pub resource Element {
    pub let feature: MetaFeature
    
    init(feature: MetaFeature) {
      self.feature = feature
    }
  }

  pub resource Collection {
    pub let elements: @[Element]

    pub fun deposit(element: @Element) {
      let hex = String.encodeHex(element.feature.bytes)
      self.elements.append(<- element)
      emit ElementDeposit(hex: hex)
    }

    pub fun withdraw(hex: String): @Element? {
      var index = 0
      while index < self.elements.length {
        let currentHex = String.encodeHex(self.elements[index].feature.bytes)
        if currentHex == hex {
          return <- self.elements.remove(at: index)
        }
        index = index + 1
      }

      return nil
    }

    pub fun getFeatures(): [MetaFeature] {
      var features: [MetaFeature] = []
      var index = 0
      while index < self.elements.length {
        features.append(
          self.elements[index].feature
        )
        index = index + 1
      }
      return features;
    }

    init() {
      self.elements <- []
    }
    destroy() {
      destroy self.elements
    }
  }

  pub fun createCollection(): @Collection {
    emit CollectionCreated()
    return <- create Collection()
  }

  // 特征收集器
  pub resource Generator {

    pub let features: {String: MetaFeature}

    init() {
      self.features = {}
    }

    pub fun generate(feature: MetaFeature): @Element? {
      // 只收集唯一的 bytes
      let hex = String.encodeHex(feature.bytes)

      if self.features.containsKey(hex) == false {
        let element <- create Element(feature: feature)
        self.features[hex] = feature

        emit ElementGenerateSuccess(hex: hex)
        return <- element
      } else {
        emit ElementGenerateFailure(hex: hex)
        return nil
      }
    }
  }

  init() {
    self.totalSupply = 0
    // 保存到存储空间

    let collection <- create Collection()

    self.account.save(
      <- create Collection(),
      to: /storage/NFTCollection
    )

    // 链接到公有空间
    self.account.link<&Collection>(
      /public/NFTCollection, // 共有空间
      target: /storage/NFTCollection // 目标路径
    )

    // collection setup
    /* 
    self.account.save(
      <- self.createCollection(),
      to: /storage/LocalEntityCollection
    )
    self.account.link<&Collection>(
      /public/LocalEntityCollection,
      target: /storage/LocalEntityCollection
    )
    */
    emit ContractInitialized()
  }


  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let name: String
    pub let description: String
    pub let thumbnail: String

    init(id:UInt64, name: String, description: String, thumbnail: String){
      self.id = id
      self.name = name
      self.description = description
      self.thumbnail = thumbnail
    }

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>()
      ]
    }
    

  }

  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {

    // Dictionary to hold the NFTs in the Collection
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init() {
      self.ownedNFTs <- {}
    }

    // withdraw removes an NFT from the collection and moves it to the caller
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Id not found")
      emit Withdraw(id: withdrawID, from: self.owner?.address)
      return <-token
    }

    // deposit takes a NFT and adds it to the collections dictionary
    // and adds the ID to the id array
    pub fun deposit(token: @NonFungibleToken.NFT) {
      let element <- token as! @Entity.NFT
      let id: UInt64 = token.id

      let oldToken <- self.ownedNFTs[id] <- token

      emit Deposit(id: id, to: self.owner?.address)
      destroy oldToken
    }

    // getIDs returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // Returns a borrowed reference to an NFT in the collection
    // so that the caller can read data and call methods from it
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return &self.ownedNFTs[id] as &NonFungibleToken.NFT
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
      let myNFT = nft as! &Entity.NFT
      return myNFT as &AnyResource{MetadataViews.Resolver}
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  // createEmptyCollection creates an empty Collection
  // and returns it to the caller so that they can own NFTs
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }



}
