// Initiate Replica Set
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "OMITTED:27017" },
    { _id: 1, host: "OMITTED:27017" },
    { _id: 2, host: "OMITTED:27017" }
  ]
});

// Create "r4c" database and user
var r4cDB = db.getSiblingDB("OMITTED");
r4cDB.createUser({
  user: "OMITTED",
  pwd: "OMITTED",
  roles: [
    { role: "readWrite", db: "OMITTED" },
    { role: "dbAdmin", db: "OMITTED" }
  ]
});

// Create "r4cdoc" database and user
var r4cdocDB = db.getSiblingDB("OMITTED");
r4cdocDB.createUser({
  user: "OMITTED",
  pwd: "OMITTED",
  roles: [
    { role: "readWrite", db: "OMITTED" },
    { role: "dbAdmin", db: "OMITTED" }
  ]
});

// Create "tagstore" database and user
var tagstoreDB = db.getSiblingDB("OMITTED");
tagstoreDB.createUser({
  user: "OMITTED",
  pwd: "OMITTED",
  roles: [
    { role: "readWrite", db: "OMITTED" },
    { role: "dbAdmin", db: "OMITTED" }
  ]
});

print("Replica set initiated and databases created.");