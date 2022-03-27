import NonFungibleToken from "./standard/NonFungibleToken.cdc"
pub contract Entity: NonFungibleToken {

  pub var totalSupply: UInt64

  pub event ContractInitialized()

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
    // 保存到存储空间
    self.account.save(
      <- create Generator(),
      to: /storage/ElementGenerator
    )
    emit GeneratorCreated()

    // 链接到公有空间
    self.account.link<&Generator>(
      /public/ElementGenerator, // 共有空间
      target: /storage/ElementGenerator // 目标路径
    )

    // collection setup
    self.account.save(
      <- self.createCollection(),
      to: /storage/LocalEntityCollection
    )
    self.account.link<&Collection>(
      /public/LocalEntityCollection,
      target: /storage/LocalEntityCollection
    )
  }


  pub resource NFT: NonFungibleToken.INFT {
    pub let id: UInt64

    init(id:UInt64){
      self.id = id
    }
  }

  pub resource Collection: Provider, Receiver, CollectionPublic {

    // Dictionary to hold the NFTs in the Collection
    pub var ownedNFTs: @{UInt64: NFT}

    // withdraw removes an NFT from the collection and moves it to the caller
    pub fun withdraw(withdrawID: UInt64): @NFT

    // deposit takes a NFT and adds it to the collections dictionary
    // and adds the ID to the id array
    pub fun deposit(token: @NFT)

    // getIDs returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt64]

    // Returns a borrowed reference to an NFT in the collection
    // so that the caller can read data and call methods from it
    pub fun borrowNFT(id: UInt64): &NFT {
        pre {
            self.ownedNFTs[id] != nil: "NFT does not exist in the collection!"
        }
    }
}

// createEmptyCollection creates an empty Collection
// and returns it to the caller so that they can own NFTs
pub fun createEmptyCollection(): @Collection {
    post {
        result.getIDs().length == 0: "The created collection must be empty!"
    }
}

}
