cd /opt/lua-resty-baselib/libs

resty -I . --shdict 'cache 100k' resty/mgo/mongo_test.lua
