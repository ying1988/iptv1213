pwd
time=$(date +%m%d%H%M)
i=0

if [ $# -eq 0 ]; then
  echo "请选择城市："
  echo "1. 广东电信（Guangdong_332）"
  echo "2. 福建电信（Fujian_114）"
  echo "3. 湖南电信（Hunan_282）"
  echo "0. 全部"
  read -t 3 -p "输入选择或在3秒内无输入将默认选择全部: " city_choice

  if [ -z "$city_choice" ]; then
      echo "未检测到输入，自动选择全部选项..."
      city_choice=0
  fi

else
  city_choice=$1
fi

# 根据用户选择设置城市和相应的stream
case $city_choice in
      1)
       city="Guangdong_332"
       stream="udp/239.77.1.152:5146"
       channel_key="广东电信"
       url_fofa="https://fofa.info/result?qbase64=InVkcHh5IiAmJiBjaXR5PSJTaGVuemhlbiIgJiYgcHJvdG9jb2w9Imh0dHAiIHx8ICJ1ZHB4eSIgJiYgY2l0eT0iR3Vhbmd6aG91IiAmJiBwcm90b2NvbD0iaHR0cCI%3D"
        ;;
    2)
        city="Fujian_114"
        stream="rtp/239.61.2.132:8708"
        channel_key="福建电信"
        url_fofa="https://fofa.info/result?qbase64=InVkcHh5IiAmJiByZWdpb249IkZ1amlhbiIgJiYgb3JnPSJDaGluYW5ldCIgJiYgcHJvdG9jb2w9Imh0dHAiIA%3D%3D"
        ;;
    3)
        city="Hunan_282"
        stream="udp/239.76.253.100:9000"
        channel_key="湖南电信"
        url_fofa="https://fofa.info/result?qbase64=InVkcHh5IiAmJiByZWdpb249Ikh1bmFuIiAmJiBwcm90b2NvbD0iaHR0cCIgJiYgb3JnPSJDaGluYW5ldCI%3D"
        ;;

    0)
        # 如果选择是“全部选项”，则逐个处理每个选项
        for option in {1..3}; do
          bash  ./fofa.sh $option  # 假定fofa.sh是当前脚本的文件名，$option将递归调用
        done
        exit 0
        ;;

    *)
        echo "错误：无效的选择。"
        exit 1
        ;;
esac

# 使用城市名作为默认文件名，格式为 CityName.ip
ipfile="${city}.ip"
only_good_ip="${city}.onlygood.ip"
rm -f $only_good_ip
# 搜索最新 IP
echo "===============从 fofa 检索 ip+端口================="
curl -o test.html "$url_fofa"
#echo $url_fofa
echo "$ipfile"
grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$' test.html | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' > "$ipfile"
rm -f test.html
# 遍历文件 A 中的每个 IP 地址
while IFS= read -r ip; do
    # 尝试连接 IP 地址和端口号，并将输出保存到变量中
    tmp_ip=$(echo -n "$ip" | sed 's/:/ /')
    echo "nc -w 1 -v -z $tmp_ip 2>&1"
    output=$(nc -w 1 -v -z $tmp_ip 2>&1)
    echo $output    
    # 如果连接成功，且输出包含 "succeeded"，则将结果保存到输出文件中
    if [[ $output == *"succeeded"* ]]; then
        # 使用 awk 提取 IP 地址和端口号对应的字符串，并保存到输出文件中
        echo "$output" | grep "succeeded" | awk -v ip="$ip" '{print ip}' >> "$only_good_ip"
    fi
done < "$ipfile"

echo "===============检索完成================="

# 检查文件是否存在
if [ ! -f "$only_good_ip" ]; then
    echo "错误：文件 $only_good_ip 不存在。"
    exit 1
fi

lines=$(wc -l < "$only_good_ip")
echo "【$only_good_ip】内 ip 共计 $lines 个"

i=0
time=$(date +%Y%m%d%H%M%S) # 定义 time 变量
while IFS= read -r line; do
    i=$((i + 1))
    ip="$line"
    url="http://$ip/$stream"
    echo "$url"
    curl "$url" --connect-timeout 5 --max-time 12 -o /dev/null >zubo.tmp 2>&1
    a=$(head -n 3 zubo.tmp | awk '{print $NF}' | tail -n 1)

    echo "第 $i/$lines 个：$ip $a"
    echo "$ip $a" >> "speedtest_${city}_$time.log"
done < "$only_good_ip"

rm -f zubo.tmp
awk '/M|k/{print $2"  "$1}' "speedtest_${city}_$time.log" | sort -n -r >"result/result_fofa_${city}.txt"
cat "result/result_fofa_${city}.txt"
ip1=$(awk 'NR==1{print $2}' result/result_fofa_${city}.txt)
ip2=$(awk 'NR==2{print $2}' result/result_fofa_${city}.txt)
rm -f "speedtest_${city}_$time.log"

# 用 3 个最快 ip 生成对应城市的 txt 文件
program="template/template_${city}.txt"

sed "s/ipipip/$ip1/g" "$program" > tmp1.txt
sed "s/ipipip/$ip2/g" "$program" > tmp2.txt
cat tmp1.txt tmp2.txt > "txt/fofa_${city}.txt"

rm -rf tmp1.txt tmp2.txt
rm -f $ipfile $only_good_ip

#--------------------合并所有城市的txt文件为:   zubo_fofa.txt-----------------------------------------

echo "广东电信,#genre#" >zubo_fofa.txt
cat txt/fofa_Guangdong_332.txt >>zubo_fofa.txt
echo "福建电信,#genre#" >>zubo_fofa.txt
cat txt/fofa_Fujian_114.txt >>zubo_fofa.txt
echo "湖南电信,#genre#" >>zubo_fofa.txt
cat txt/fofa_Hunan_282.txt >>zubo_fofa.txt