print(package.path)

--pairs&ipairs
--同:都是遍历集合(表,数组)
--异:ipairs仅仅遍历值,按照索引升序遍历,
--索引中断停止遍历,不返回nil,返回0
--pairs能遍历集合的所有元素,可以返回nil

local tb = {
    [1] = 'a',
    [2] = 'b',
    [3] = 'c',
    'd',
    first=1,
    ['second'] = 2,
    [5] = 'z',
}

for i, v in pairs(tb) do
    print(i, v)
end

for i, v in ipairs(tb) do
    print(i, v)
end
