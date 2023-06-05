# WSLg + Docker + Arduino IDE

## 背景

**Arduino IDE のコンパイルが遅い！** と感じている方は多いようで、様々な方法が提案されています。  
しかし、

-   **ccache を使う**  
    効果なし。逆に悪化。
-   **PlatformIO への移行**  
    Arduino IDE と完全互換ではなく、追加の構成が必要。
-   **Linux を使う**  
    Windows をメインで使いたい。

などなど...いろいろ課題があります。  
どうにかできないかと考えていたところ、最近 WSL2 で GUI が使えるようになったという話を耳にしました（今更）。  

これをうまく使えば Windows を使いながら Linux でのコンパイルが早いという恩恵を享受できるのでは？と閃いたのですが、  
既にやっている方がいらっしゃいました...  

[![alt設定](http://img.youtube.com/vi/so0xr_1rSZM/0.jpg)](https://www.youtube.com/watch?v=so0xr_1rSZM)

ただ、WSL2 内の環境をあまり汚したくなかったので Docker を使って環境を分離できないか試してみたところ、ある程度うまくいったので、備忘録としてまとめました。
余談ですが、コンテナ内部にボードマネージャ自体も内包するため、Docker のイメージファイルは 6GB 級という巨大イメージになりました。  

## ベンチマーク結果

構築方法の詳細を語る前に、どのくらい高速化されるのかテストした結果を提示します。  
Windows 上で実行した Arduino IDE と WSLg + Docker 上で実行した Arduino IDE で、ビルドにかかる時間（秒数）の比較を行いました。  
検証用のスケッチとして、個人プロジェクトに加えて [robo8080](https://github.com/robo8080) 様と [GOB52](https://github.com/GOB52) 様のプログラムを使用させていただきました。

#### [M5Core2_SG90_StackChan_VoiceText_Ataru](https://github.com/robo8080/M5Core2_SG90_StackChan_VoiceText_Ataru) @robo8080

|              | ビルド１回目<br>（キャッシュ無し） | ビルド２回目<br>（キャッシュ有り） |
| :----------: | :--------------------------------: | :--------------------------------: |
|   Windows    |                316                 |                 38                 |
| WSL + Docker |                 90                 |                 8                  |
|   高速化率   |               3.5 倍               |               4.8 倍               |

#### [M5Stack_FlipBookSD](https://github.com/GOB52/M5Stack_FlipBookSD) @GOB52

|              | ビルド１回目<br>（キャッシュ無し） | ビルド２回目<br>（キャッシュ有り） |
| :----------: | :--------------------------------: | :--------------------------------: |
|   Windows    |                154                 |                 20                 |
| WSL + Docker |                 48                 |                 5                  |
|   高速化率   |               3.2 倍               |               4.0 倍               |

#### 個人プロジェクト

|              | ビルド１回目<br>（キャッシュ無し） | ビルド２回目<br>（キャッシュ有り） |
| :----------: | :--------------------------------: | :--------------------------------: |
|   Windows    |                501                 |                 77                 |
| WSL + Docker |                140                 |                 25                 |
|   高速化率   |               3.6 倍               |               3.1 倍               |

**圧　倒　的　高　速　化　！**  
ビルド１回目で平均して約 3.4 倍の高速化、ビルド２回目で平均して約 4.0 倍もの高速化を達成しています。  
これは嬉しい 😊

## 検証環境

|                            |                     |
| -------------------------- | ------------------- |
| CPU                        | i7-10700            |
| OS                         | Windows 11 Pro 22H2 |
| WSL バージョン             | 1.2.5.0             |
| カーネル バージョン        | 5.15.90.1           |
| WSLg バージョン            | 1.0.51              |
| Docker                     | 24.0.2              |
| Docker compose             | v2.18.1             |
| WSL ディストリビューション | Ubuntu              |


## 構築手順

### 0. WSL2 の更新

WSL の導入と Docker の導入は完了しているものとします。  
最初に Windows Terminal を管理者権限で開き、下記コマンドを実行します。

```console
> wsl --update
> wsl --shutdown
```

### 1. WSL2 内での USB 有効化

Windows Terminal で下記コマンドを実行します。

```console
> winget install --interactive --exact dorssel.usbipd-win
```

WSL2 を開き、下記コマンドを実行します。

```console
> sudo apt update
> sudo apt upgrade -y

> sudo apt install -y linux-tools-5.4.0-77-generic hwdata
> sudo update-alternatives --install /usr/local/bin/usbip usbip /usr/lib/linux-tools/5.4.0-77-generic/usbip 20
```

PC を再起動します。  
M5Stack 等を PC に接続した後、Windows Terminal 側で下記コマンドを実行します。  
リストに接続した USB 機器があることを確認します。  
（下記例だと `1-7` が M5Stack に接続されています）

```console
> usbipd wsl list

BUSID  VID:PID    DEVICE                                                        STATE
1-1    045e:02fe  Xbox Wireless Adapter for Windows                             Not attached
1-7    10c4:ea60  Silicon Labs CP210x USB to UART Bridge (COM3)                 Not attached
1-9    046d:c52b  Logitech USB Input Device, USB 入力デバイス, Logicool Uni...  Not attached
1-10   0a12:0001  Generic Bluetooth Radio                                       Not attached
1-11   0b05:18f3  AURA LED Controller, USB 入力デバイス                         Not attached
1-12   08bb:2704  USB Audio DAC, USB 入力デバイス                               Not attached
1-18   0411:01e7  USB 大容量記憶装置                                            Not attached
3-3    046d:085c  c922 Pro Stream Webcam, C922 Pro Stream Webcam                Not attached
```

該当する BUSID が確認できたら、下記コマンドを実行します。  
（`1-7` は接続する BUSID に応じて変えます）  
このコマンドで WSL2 に USB を接続しています。  
ステータスが Attached になれば OK です。

```console
> usbipd wsl attach --busid 1-7
> usbipd wsl list

BUSID  VID:PID    DEVICE                                                        STATE
1-1    045e:02fe  Xbox Wireless Adapter for Windows                             Not attached
1-7    10c4:ea60  Silicon Labs CP210x USB to UART Bridge (COM3)                 Attached - Ubuntu
1-9    046d:c52b  Logitech USB Input Device, USB 入力デバイス, Logicool Uni...  Not attached
1-10   0a12:0001  Generic Bluetooth Radio                                       Not attached
1-11   0b05:18f3  AURA LED Controller, USB 入力デバイス                         Not attached
1-12   08bb:2704  USB Audio DAC, USB 入力デバイス                               Not attached
1-18   0411:01e7  USB 大容量記憶装置                                            Not attached
3-3    046d:085c  c922 Pro Stream Webcam, C922 Pro Stream Webcam                Not attached
```

WSL2 から Windows へ接続を戻す場合は、下記コマンドを使用します。  
（`1-7` は接続する BUSID に応じて変えます）

```console
> usbipd wsl detach --busid 1-7
```

### 2. ファイルの移動

コンテナ内の Arduino で使用したいライブラリとスケッチを移動します。  

Docker コンテナ内で使用するライブラリやスケッチを後で説明する docker-compose から直接ボリューム共有することもできますが、WSL2 内から Windows 領域へのファイルアクセスが非常に遅いため、ビルド時にボトルネックになってしまいます。  
それを回避するために初めから WSL2 内部にファイルを移動しておこうという作戦です。

<img src="https://raw.githubusercontent.com/takkaO/ArduinoContainerWSL/images/fig_flow.png" width="500px">

まず、Windows 側からエクスプローラを開きます。  
私がインストールしているディストリビューションは Ubuntu なので、左側のリストの一番下に「Ubuntu」とあります。
ディストリビューションが異なる場合は適宜読み替えてください。  
そこをクリックして任意のフォルダ内にライブラリとスケッチをコピーします。  
本記事では下記のようにします。  

ライブラリ：**/home/usr/Arduino/libraries**  
スケッチ　：**/home/usr/ArduinoSketch**

<img src="https://raw.githubusercontent.com/takkaO/ArduinoContainerWSL/images/fig_explorer1.png" width="650px">

<img src="https://raw.githubusercontent.com/takkaO/ArduinoContainerWSL/images/fig_explorer2.png" width="650px">

コピーが完了すれば OK です。  

### 3. Docker コンテナのビルド

リポジトリをクローンします。

```console
> git clone https://github.com/takkaO/ArduinoContainerWSL.git
> cd ArduinoContainerWSL
```

コンテナイメージをビルドします。  
ビルド時にボードマネージャをダウンロードしますが、通信状況によってはビルド途中で失敗することがあります。  
その時は再度ビルドを試みてください。  
特に M5Stack のボードマネージャは失敗しやすいです。  

```console
docker compose build
```

また、導入する各ソフトウェアのバージョンは下記の通りです。  
バージョンの変更や追加は Dockerfile を修正してください。  
一時的に変更するだけであれば、コンテナ起動後に Arduino IDE から行っても構いません。  

| 項目                     | バージョン |
| ------------------------ | :--------: |
| Arduino IDE              |  v1.8.19   |
| ESP32 ボードマネージャ   |   v2.0.4   |
| M5Stack ボードマネージャ |   v2.0.4   |

### 4. コンテナの起動

`.env` 修正し、**「2. ファイルの移動」** で移動したフォルダパスを指定します。  
`compose.yml` を直接編集しても構いません。

```r
# 使用しているディストリビューション
# Windows から見た時のパスで使用
DISTRIBUTION=Ubuntu

# ライブラリフォルダのWSL内のパス
# Windows でのパス区切り（\）を使う
LIB_PATH=\home\usr\Arduino\libraries

# スケッチがあるフォルダのWSL内のパス
# Windows でのパス区切り（\）を使う
SKETCH_PATH=\home\usr\ArduinoSketch

# スケッチの名前
SKETCH_NAME=my_sketch
```

編集が終わったら、Windows Terminal を開き、コンテナを起動します。  
Arduino IDE の画面が表示され、スケッチが開かれていれば成功です。  
スケッチが開かれない場合は、パスが間違っている可能性があります。  
Arduino IDE を終了すれば、コンテナも自動的に終了します。  

```console
> docker compose up -d
```

<img src="https://raw.githubusercontent.com/takkaO/ArduinoContainerWSL/images/fig_wsl_arduino.png" width="350px">

## まとめ

Arduino IDE を Docker コンテナ内から起動し、コンパイルと書き込みを行いました。  
Linux 上の Arduino IDE だと ESP32 のコンパイルが早いという特徴（？）を利用することができるようになり、平均して約 3.4 倍の高速化を実現できました。  
この方法の特徴をまとめると下記のようになります。

-   **利点**
    -   簡単にスクラップ＆ビルドができる
    -   Arduino IDE と完全互換
    -   環境を独立させることができる
    -   Windows を利用しながらビルドを約 3.4 倍高速化できる
-   **欠点**
    -   環境構築がやや面倒
    -   USB 接続の際にひと手間必要
    -   事前にライブラリやスケッチの移動が必要（WSL2 が遅いから）
    -   Docker イメージが巨大 (6GB)

## References

-   [WSL2 のインストールを分かりやすく解説【Windows10/11】 | チグサウェブ](https://chigusa-web.com/blog/wsl2-win11/)
-   [Can I use the new WSLg with Docker? : r/bashonubuntuonwindows](https://www.reddit.com/r/bashonubuntuonwindows/comments/n2nthu/comment/hh0w4cw/?utm_source=share&utm_medium=web2x&context=3)
-   [docker-wslg-gui-template/.env.wslg at main · SARDONYX-sard/docker-wslg-gui-template · GitHub](https://github.com/SARDONYX-sard/docker-wslg-gui-template/blob/main/docker/.env.wslg)
-   [zenn/9726126c4a67ffb66509.md at master · SARDONYX-sard/zenn · GitHub](https://github.com/SARDONYX-sard/zenn/blob/master/articles/9726126c4a67ffb66509.md)
-   [WSL2 USB カメラ+他の USB 機器 2022 年 09 月 06 日版](https://zenn.dev/pinto0309/articles/e1432253d29e30)
-   [Docker コンテナから USB デバイスへのアクセス | Armadillo サイト](https://armadillo.atmark-techno.com/blog/10899/4191)
-   [GOB52/M5Stack_FlipBookSD: This application works like a video playback by playing back the combined images in SD with sound.](https://github.com/GOB52/M5Stack_FlipBookSD)
-   [robo8080/M5Core2_SG90_StackChan_VoiceText_Ataru: M5Core2_SG90_StackChan_VoiceText_Ataru](https://github.com/robo8080/M5Core2_SG90_StackChan_VoiceText_Ataru)
