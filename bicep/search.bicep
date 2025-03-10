param location string = 'westeurope'
param cognitiveSearchName string = 'jcchatbot-search'

resource cognitiveSearch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: cognitiveSearchName
  location: location
  sku: {
    name: 'standard'
  }
}

output searchName string = cognitiveSearch.name
output searchId string = cognitiveSearch.id
