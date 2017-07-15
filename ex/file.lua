print(package.path)

--io.input&io.open区别
--打开文件
file = io.input('file.lua')

--逐行读取内容
repeat
    line = io.read()
    if nil == line then
        break
    end
    print(line)
until(false)
--关闭文件
io.close()

file = io.open('file.lua')
--使用file:lines读取文件
for line in file:lines() do
    print(line)
end
io.close()


file = io.open('file.lua', 'a+')
-- io.output(file) --默认输出文件上
-- io.write("\nprint(233)") --写入文件
file:write("\nprint(233)") --写入文件
file:close()
