"""Schema definition for NFT (Non-Fungible Token) metadata.

This schema defines the structure for NFT metadata,
including token information, attributes, and media content.
"""

from lux_sdk.signals import SignalSchema

class NFTMetadataSchema(SignalSchema):
    """Schema for NFT metadata and attributes."""
    
    def __init__(self):
        """Initialize the NFTMetadataSchema."""
        super().__init__(
            name="nft_metadata",
            version="1.0",
            description="Schema for NFT metadata and attributes",
            schema={
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the NFT metadata was created or last updated"
                    },
                    "token_id": {
                        "type": "string",
                        "description": "The unique identifier for the NFT"
                    },
                    "contract_address": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{40}$",
                        "description": "The NFT contract address"
                    },
                    "chain_id": {
                        "type": "integer",
                        "description": "The blockchain network ID"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the NFT"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the NFT"
                    },
                    "image": {
                        "type": "string",
                        "format": "uri",
                        "description": "URI to the NFT image"
                    },
                    "external_url": {
                        "type": "string",
                        "format": "uri",
                        "description": "External URL for viewing the NFT"
                    },
                    "attributes": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "trait_type": {
                                    "type": "string",
                                    "description": "The type of trait"
                                },
                                "value": {
                                    "description": "The value of the trait",
                                    "oneOf": [
                                        {"type": "string"},
                                        {"type": "number"},
                                        {"type": "boolean"}
                                    ]
                                },
                                "display_type": {
                                    "type": "string",
                                    "enum": ["number", "boost_percentage", "boost_number", "date"],
                                    "description": "How the trait should be displayed"
                                },
                                "max_value": {
                                    "type": "number",
                                    "description": "Maximum value for numeric traits"
                                },
                                "trait_count": {
                                    "type": "integer",
                                    "description": "Number of items with this trait"
                                },
                                "order": {
                                    "type": "integer",
                                    "description": "Order in which to display the trait"
                                }
                            },
                            "required": ["trait_type", "value"]
                        }
                    },
                    "media": {
                        "type": "object",
                        "properties": {
                            "raw": {
                                "type": "string",
                                "format": "uri",
                                "description": "URI to the raw media file"
                            },
                            "gateway": {
                                "type": "string",
                                "format": "uri",
                                "description": "URI to the gateway-hosted media"
                            },
                            "thumbnail": {
                                "type": "string",
                                "format": "uri",
                                "description": "URI to the thumbnail"
                            },
                            "format": {
                                "type": "string",
                                "description": "Media format (e.g., 'image/png')"
                            },
                            "size": {
                                "type": "integer",
                                "description": "Size of the media in bytes"
                            }
                        }
                    },
                    "animation_url": {
                        "type": "string",
                        "format": "uri",
                        "description": "URI to the animation/multimedia asset"
                    },
                    "background_color": {
                        "type": "string",
                        "pattern": "^#[0-9a-fA-F]{6}$",
                        "description": "Background color in hex format"
                    },
                    "youtube_url": {
                        "type": "string",
                        "format": "uri",
                        "description": "URL to a YouTube video"
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "collection": {
                                "type": "object",
                                "properties": {
                                    "name": {"type": "string"},
                                    "family": {"type": "string"}
                                }
                            },
                            "generation": {
                                "type": "integer",
                                "description": "Generation number for generative art"
                            },
                            "dna": {
                                "type": "string",
                                "description": "Unique DNA string for generative NFTs"
                            },
                            "date": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation date"
                            },
                            "compiler": {
                                "type": "string",
                                "description": "Compiler used for generative art"
                            }
                        }
                    }
                },
                "required": [
                    "timestamp",
                    "token_id",
                    "contract_address",
                    "chain_id",
                    "name",
                    "description",
                    "image"
                ]
            }
        ) 