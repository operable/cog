kill -9 `cat /var/run/operable/cog.pid`
rm /var/run/operable/cog.pid
echo "Cog stopped. We will miss you."
