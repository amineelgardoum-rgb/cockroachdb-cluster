from pymongo import MongoClient
HTTP_URL="mongodb://mongos:27020"
client=MongoClient(HTTP_URL)
try:
    client.admin.command('ping')
    print("Connection Successful.")
except Exception as e:
    print(f"There is an exception :{e}")
    
db=client["medical"]
for i, collection in enumerate(db.list_collection_names()):
    print(f"Collection {i}: {collection}.")