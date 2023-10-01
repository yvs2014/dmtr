:

key='/usr/share/keyrings/googlelinux.gpg'
key_url='https://dl-ssl.google.com/linux/linux_signing_key.pub'
repo_url='https://storage.googleapis.com/download.dartlang.org/linux/debian'
list='/etc/apt/sources.list.d/dart_stable.list'
arch="$(dpkg --print-architecture)"

if [ ! -f "$key" ]; then
	sudo apt install -y apt-transport-https
	curl -o- "$key_url" | sudo gpg --dearmor -o "$key"
	echo "deb [signed-by=$key arch=$arch] $repo_url stable main" | sudo tee "$list"
	sudo apt update
fi
sudo apt install -y dart

