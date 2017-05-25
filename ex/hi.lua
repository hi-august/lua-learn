-- 这是单行注释
--[[
  这是块注释
--]]
--[[
  字符串
  布尔类型
--]]
print("hi")
--lua默认为全局变量,加local变为局部变量
num = 1024
print(num)
-- 没有声明的变量是nil
v = UndefinedVariable
print(v)

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
    -- 拼接字符串
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
function fib(n)
    if n < 2 then return 1 end
    return fib(n - 2) + fib(n - 1)
end
print(fib(2))
