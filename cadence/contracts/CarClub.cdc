import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

access(all) contract CarClub: NonFungibleToken {

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let CollectionPrivatePath: PrivatePath
    access(all) let AdminStoragePath: StoragePath

    access(all) var totalSupply: UInt64

    access(all) struct CarClubMetadata {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let description: String
        access(all) let image: String
        access(all) let traits: {String: String}

        init(id: UInt64 ,name: String, description: String, image: String, traits: {String: String}) {
            self.id = id
            self.name=name
            self.description = description
            self.image = image
            self.traits = traits
        }
    }

    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let description: String
        access(all) var image: String
        access(all) let traits: {String: String}

        init(id: UInt64, name: String, description: String, image: String, traits: {String: String}) {
            self.id = id
            self.name=name
            self.description = description
            self.image = image
            self.traits = traits
        }

        access(all) fun revealThumbnail() {
            let urlBase = self.image.slice(from: 0, upTo: 47)
            let newImage = urlBase.concat(self.id.toString()).concat(".png")
            self.image = newImage
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- CarClub.createEmptyCollection(nftType: Type<@NFT>())
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.NFTView>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<CarClub.CarClubMetadata>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Traits>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.image,
                            path: nil
                        )
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://driverz.world")
                case Type<MetadataViews.NFTCollectionData>():
                    return CarClub.resolveContractView(resourceType: Type<@NFT>(), viewType: Type<MetadataViews.NFTCollectionData>())
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return CarClub.resolveContractView(resourceType: Type<@NFT>(), viewType: Type<MetadataViews.NFTCollectionDisplay>())
                case Type<CarClub.CarClubMetadata>():
                    return CarClub.CarClubMetadata(
                        id: self.id,
                        name: self.name,
                        description: self.description,
                        image: self.image,
                        traits: self.traits
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([])
                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = []
                    for trait in self.traits.keys {
                        traits.append(MetadataViews.Trait(
                            name: trait,
                            value: self.traits[trait]!,
                            displayType: nil,
                            rarity: nil
                        ))
                    }
                    return MetadataViews.Traits(traits)
            }
            return nil
        }
    }

    access(all) resource interface CollectionPublic {
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) 
        access(all) view fun getIDs(): [UInt64]
        access(all) fun borrowCarClub(id: UInt64): &CarClub.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow Car Club reference: The ID of the returned reference is incorrect"
            }
        }
    }

    access(all) resource Collection: CollectionPublic, NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            return <-token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @CarClub.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            destroy oldToken
        }

         access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@NFT>()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@NFT>()
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)
        }

        access(all) fun borrowCarClub(id: UInt64): &CarClub.NFT? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as! &NFT
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- CarClub.createEmptyCollection(nftType: Type<@NFT>())
        }

        init () {
            self.ownedNFTs <- {}
        }
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

	access(all) resource Admin {
		access(all) fun mintNFT(
		recipient: &{NonFungibleToken.CollectionPublic},
		name: String,
        description: String,
        image: String,
        traits: {String: String}
        ) {
            CarClub.totalSupply = CarClub.totalSupply + 1
            
			recipient.deposit(token: <- create CarClub.NFT(
			    id: CarClub.totalSupply,
                name: name,
                description: description,
			    image:image,
                traits: traits
            ))
		}
	}

     access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                let collectionData = MetadataViews.NFTCollectionData(
                    storagePath: self.CollectionStoragePath,
                    publicPath: self.CollectionPublicPath,
                    publicCollection: Type<&Collection>(),
                    publicLinkedType: Type<&Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <- CarClub.createEmptyCollection(nftType: Type<@NFT>())
                    })
                )
                return collectionData
            case Type<MetadataViews.NFTCollectionDisplay>():
                let squareMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://driverz.world/DriverzNFT-logo.png"
                    ),
                    mediaType: "image"
                )
                let bannerMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://driverz.world/DriverzNFT-logo.png"
                    ),
                    mediaType: "image"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "Driverz Car Club",
                    description: "Driverz Car Club Collection",
                    externalURL: MetadataViews.ExternalURL("https://driverz.world/"),
                    squareImage: squareMedia,
                    bannerImage: bannerMedia,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/DriverzWorld"),
                        "discord": MetadataViews.ExternalURL("https://discord.gg/driverz"),
                        "instagram": MetadataViews.ExternalURL("https://www.instagram.com/driverzworld")
                    }
                )
        }
        return nil
    }

    init() {
        self.CollectionStoragePath = /storage/CarClubCollection
        self.CollectionPublicPath = /public/CarClubCollection
        self.CollectionPrivatePath = /private/CarClubCollection
        self.AdminStoragePath = /storage/CarClubMinter

        self.totalSupply = 0

        let minter <- create Admin()
        self.account.storage.save(<-minter, to: self.AdminStoragePath)

        let collection <- create Collection()
        self.account.storage.save(<-collection, to: CarClub.CollectionStoragePath)
        let collectionCap = self.account.capabilities.storage.issue<&Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(collectionCap, at: self.CollectionPublicPath)
    }
}