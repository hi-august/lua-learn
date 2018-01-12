cd /opt/lua-learn/lualib

resty -I . --shdict 'cache 100k' test/mongo_test.lua
