FROM debian:bullseye-20230522-slim

RUN apt update && apt upgrade -y
RUN apt install x11-apps wget xz-utils libxtst6 fonts-migmix locales curl python3 python-is-python3 python3-pip -y

RUN pip install pyserial

# ja_JP.UTF-8の行のコメントを解除
RUN sed -i -E 's/# (ja_JP.UTF-8)/\1/' /etc/locale.gen
RUN locale-gen
RUN update-locale LANG=ja_JP.UTF-8
ENV LANG ja_JP.UTF-8  
ENV LANGUAGE ja_JP.UTF-8
ENV LC_ALL ja_JP.UTF-8

# Arduino IDE のインストール
WORKDIR /home
RUN wget https://downloads.arduino.cc/arduino-1.8.19-linux64.tar.xz
RUN tar xvf arduino-1.8.19-linux64.tar.xz
RUN cd arduino-1.8.19 && ./install.sh
RUN cd /usr/bin && ln -s /home/arduino-1.8.19/arduino

# ArduinoIDE にボードマネージャ URL を追記
RUN mkdir -p /root/.arduino15
RUN echo "boardsmanager.additional.urls=https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json,https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/arduino/package_m5stack_index.json,https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json" >> /root/.arduino15/preferences.txt 

# Arduino-cli のインストール
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
RUN cd /usr/bin && ln -s /home/bin/arduino-cli

# Arduino-cli にボードマネージャ URL を追加
RUN arduino-cli config init
RUN arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
RUN arduino-cli config add board_manager.additional_urls https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/arduino/package_m5stack_index.json
RUN arduino-cli config add board_manager.additional_urls https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json

# ボードマネージャのインストール
RUN arduino-cli core update-index
RUN arduino-cli core install esp32:esp32@2.0.4
RUN arduino-cli core install m5stack:esp32@2.0.4

CMD ["arduino"]