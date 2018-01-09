-- 这是单行注释
--[[
  这是块注释
--]]
--[[
  字符串
  布尔类型
--]]

--搜索路径
print(package.path, type(package.path))
print("hi")
--lua默认为全局变量,加local变为局部变量
--一般添加local局部变量
num = 1024
print(num)
-- 没有声明的变量是nil
v = UndefinedVariable
print(v)
b = 0
-- b为0是true,和python不一样
if b then
    print(233)
else
    print(nil)
end

--lua中可以使用单引号或者双引号表示字符串
--还可以使用[[

local str1 = 'hi'
local str2 = "hello"
local str3 = [["hi", 'world']]
local str4 = [=[string has a [[]]]=]
print(str1) --out: hi
print(str2) --out: hello
print(str3) --out: hi,world
print(str4) --out: string has a [[]]
--lua中的字符串是不可变

--返回acsii码
print(string.byte('abc', 1, 3)) --out: 97 98 99返回ascii码
print(string.byte('abc', 3))
print(string.byte('abc'))
--返回ascii码组成的字符串
print(string.char(96, 97, 98)) --out: `ab
print(string.char()) --参数为空,默认0
print(string.char(65, 66)) --out: AB
--返回小写字母的字符串
print(string.lower('HI你好'))
--返回大写字母的字符串
print(string.upper('hi'))
--返回字符串的长度
--我们一般使用使用#运算符取lua字符串的长度
print(string.len('hi, world'))
print(#str1)
--字符串查找find
--返回开始,结束索引
--没有匹配到返回nil
print('\n\n\n2333')
local find = string.find
print(find('abc, cba', 'ab'))
print(2222222222222222222)
print(find('abc, cba', 'ab', 2)) --从索引为2位置开始匹配字符串ab
print(find('abc, cba', 'ab'), -2) --从索引-2位置匹配
--格式化字符串format
print(string.format('%.3f', 3.1415926))
print(string.format('%d/%d/%d today is: ', 1, 7, 2017))
--字符串匹配match,gmatch
print(string.match('hi world', 'hi'))
print(string.match('hi world', 'hi'), 2)
print(string.match('hi world', 'hello'))
print(string.match('1/7/2017 today is:', '%d+/%d+/%d+'))

s = 'hello world from lua'
for w in string.gmatch(s, '%a+') do --%a显示字母的字符串
    print(w)
end
--字符串拷贝rep
print(string.rep('abc', 3))
--字符串切片sub
print(string.sub('hi, world', 5, 9))
print(string.sub('hi, world', 5))
print(string.sub('hi, world', 5, 1))
print(string.sub('hi, world', -5, -1))
--字符串替换gsub
print(string.gsub('hi world', 'hi', 'hello'))
--字符串反转reverse
print(string.reverse('hi'))

local order = 3.99
local score = 98.01
print(math.floor(order)) --out: 3 向上取整
print(math.ceil(score)) --out: 99 向下取整

--table,相当于python中的dict
local corp = {
    web = 'youtube.com',
    tel = 123456789,
    staff = {'tom', 'jack', 'nana'},
    10067, --相当于[1]=10067
    20078,
    [10] = 360,
    ["city"] = "beijing",
}
print(corp.web) --out: youtube.com
print(corp['tel']) --out: 123456789
print(corp.staff[1]) --out: tom lua下标从1开始
print(corp[10]) --out: 360
print(corp[1]) --out: 10067

--获取长度,table.getn
--getn,#只会计数[1]值,对于存在key的键值不计算在内
--不要lua的table中使用nil
--如果要删除一个元素,直接remove
--不要使用nil取代替
local color={first='red', 'blue', third='green', 'yellow', 'black'}
print(color['first']) --out: red
print(color[1]) --out: blue
print(color['third']) --out: green
print(color[2]) --out: yellow
print(color[3]) --out: nil
print('color has getn'..table.getn(color))
print('color has #'..#color)
--正确追加到table末尾
color[#color+1] = 'pink'
print(color[4])
--对于table中都是string或者number
--可以用table.concat连接成字符串
print(table.concat(color)) --out: blueyellowblackpink
print(table.concat(color, '|')) --out: blue|yellow|
print(table.concat(color, '_', 4, 2)) --out: nil
print(table.concat(color, '_', 2, 4)) --out: yellow_black_
--table.insert追加元素
local b = {2, 3} --==b[1] = 2,b[2] = 3
--向索引pos1插入9,其他元素向后移动
--默认pos是表的长度加1
table.insert(b, 1, 9)
table.insert(b, 233)
--取table最后一个值
print(b[#b])
--返回最大的索引编号
--没有正索引编号,返回0
--是高代价操作
local c = {}
c[-3] = 7
print(table.maxn(c)) --out: 0
c[3] = 1
print(table.maxn(c))
print(c[3])
--table.remove删除元素
--默认删除最后一个
--索引pos只能是number类型
--并返回这个被删除的元素
--类似python set中的pop
print(table.remove(b))
print(table.remove(b, 1))
print(b[1])
--table.sort,默认从小到大
--使用compare函数进行排序
local function compare(x, y)
    return x > y
end
local d = {1, 66, 7, 3, 4, 33}
table.sort(d)
print(d[1], d[2], d[3])
table.sort(d, compare)
print(d[1], d[2], d[3])
--table.new, table.clear前者用来预分配lua table空间
--后者用来高效释放table空间

--元表(metatable)
--setmetatable设置为元表
local tb = {}
local m_tb = {}
setmetatable(tb, m_tb)
local m_tb2 = setmetatable({}, {})
print(getmetatable(m_tb))
print(22222222)
local set1 = {1, 3, 5}
local set2 = {2, 4, 6}

--将用于重载__add函数,第一个参数为self,类python self
local union = function (self, another)
    local set = {}
    local result = {}
    --利用数组来确保集合没有重复
    for i, j in pairs(self) do set[j] = true end
    for i, j in pairs(another) do set[j] = true end

    --加入结果集合
    for i, j in pairs(set) do table.insert(result, i) end
    return result
end

setmetatable(set1, {__add = union }) --重载set1表__add方法
print(getmetatable(set1))
print(getmetatable("Hello World"))
local set3 = set1 + set2
for _, j in pairs(set3) do
    print(j)
end

-- while loop
sum = 0
num = 1
while num <= 100 do
    sum = sum + num
    num = num + 1
end
print(sum)

-- if else判断
-- and,or,not
age = 9
if age > 9 then
    print("big than 9")
elseif age < 9 then
    print("less than 9")
elseif age == 9 then
    -- ..拼接字符串
    print("equal to 9 = "..age)
end

-- for loop
-- 100以内奇数和
sum = 0
-- i:start, 100:end, 2:步长
for i = 1, 100, 2 do
    sum = sum + i
end
print(sum)

-- 递归函数
-- lua中,函数也是一种数据类型
-- 可以存储在变量中,
-- 可以通过变量传递给其他函数
-- 也可以作为其他函数的返回值
function fib(n)
    if n < 2 then return 1 end
    return fib(n - 2) + fib(n - 1)
end
print(fib(2))
