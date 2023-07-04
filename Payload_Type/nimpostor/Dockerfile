FROM nimlang/nim
#ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get update -y
RUN apt-get install -y build-essential gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 python3-pip 
RUN nimble install -y winim nimcrypto sysrandom ptr_math byteutils shlex
RUN python3 -m pip install dynaconf==3.1.4 aio_pika pycrypto pycryptodome mythic-payloadtype-container==0.1.8
RUN apt-get update -y
RUN wget https://raw.githubusercontent.com/monoxgas/sRDI/master/Python/ShellcodeRDI.py -O /opt/ShellcodeRDI.py
RUN apt-get update -y
RUN apt-get install -y software-properties-common apt-utils make zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl llvm libncurses5-dev libncursesw5-dev tk-dev libffi-dev liblzma-dev
ENTRYPOINT ["/Mythic/mythic/payload_service.sh"]
