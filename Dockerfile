FROM kalilinux/kali-rolling

ENV TZ=Europe/Athens
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ADD users.txt .
ADD passwords.txt .

RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y software-properties-common && \
    apt-get install hydra-gtk -y

#ENTRYPOINT ["tail"]

#CMD ["-f", "/dev/null"]

# on the host machine run: sudo docker build -t groot .
#
