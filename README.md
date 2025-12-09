# ServerstatusGoDeploy

scripts for serverstatus fast deploy

# Compatiable

with old serverstatus server

## Server

### Using docker to deploy
1.simple deploy
```
docker run -d --restart=always --name=serverstatus -v /home/docker/serverstatus/server-config.json:/ServerStatus/server/config.json -v /tmp/serverstatus-monthtraffic:/usr/share/nginx/html/json -p your-hostwebport:80 -p 35601:35601 docker.1panel.live/cppla/serverstatus:1.1.5
```
2.custom web deploy
```
docker run -d --restart=always --name=serverstatus -v /home/docker/serverstatus/server-config.json:/ServerStatus/server/config.json -v /home/docker/serverstatus/web:/usr/share/nginx/html -v /tmp/serverstatus-monthtraffic:/usr/share/nginx/html/json -p your-hostwebport:80 -p 35601:35601 docker.1panel.live/cppla/serverstatus:1.1.5
```

### config.json example
```
{
	"servers": [
		{
			"username": "AIFront",
			"name": "AIFront",
			"type": "Dedicated",
			"host": "192.168.1.40",
			"location": "CN",
			"password": "pass",
			"monthstart": 1
		},
		{
			"username": "Router",
			"name": "Router",
			"type": "Dedicated",
			"host": "192.168.1.42",
			"location": "CN",
			"password": "pass",
			"monthstart": 1
		}
	],
	"watchdog": [
		{
			"name": "memory high warning",
			"rule": "(memory_used/memory_total)*100>90",
			"interval": 5300,
			"callback": "http://serverchanorpushoo-ip/send?chan=group1&title=ServerStatus&desp="
		},
		{
			"name": "offline warning",
			"rule": "online4=0&online6=0",
			"interval": 5600,
			"callback": "http://serverchanorpushoo-ip/send?chan=group1&title=ServerStatus&desp="
		}
	]

}

```

## Client

### For Windows
download the windows directory,click the bat script.

### For Openwrt/Linux
download the Linux directory,give 777 privilege for the .sh script and run it.

### Docker version
```
docker run --network=host --name=serverstatusclient --restart=always -e SERVER="serverstatus-server-ip" -e USER="client-user" -e PASSWORD="client-pass" -e PROBEPORT="35601" docker.1panel.live/dtcokr/serverstatus:client
```
