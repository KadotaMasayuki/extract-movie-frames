#!/bin/bash

# 使用方法：
#   extract_frames.sh <動画ファイル1> [ <動画ファイル2> .. ]
#   extract_frames.sh -c <分割数> <動画ファイル1> [ <動画ファイル2> .. ]
#   extract_frames.sh -t <分割間隔秒> <動画ファイル1> [ <動画ファイル2> .. ]


# 分割数等を指定しないときの、最低分割数
DEFAULT_MIN_CNT=60
# 分割数等を指定しないときの、分割間隔秒
DEFAULT_DURATION_SEC=120


if [ "$#" -lt 1 ]; then
	echo "Usage:"
	echo "   $0 <video_file> [ <video_file> ... ]"
	echo "   $0 -c <split_count> <video_file> [ <video_file> ... ]"
	echo "   $0 -t <split_duration_sec> <video_file> [ <video_file> ... ]"
	exit 1
fi

SPLIT_CNT=0
SPLIT_DURATION=0
if [ "$1" == "-c" ]; then
	# -c 分割数
	if [ "$#" -lt 3 ]; then
		echo "Usage:"
		echo "   $0 -c <split_count> <video_file> [ <video_file> ... ]"
		exit 1
	fi
	# 半角数値のみ（整数のみ）
	if [[ ! "$2" =~ ^[0-9]+$ ]]; then
		echo "Usage:"
		echo "   $0 -c <split_count> <video_file> [ <video_file> ... ]"
		echo "         --> split_count accept only integer"
		exit 1
	fi
	SPLIT_CNT="$2"
	# 引数２つぶんを捨てる
	shift
	shift
elif [ "$1" == "-t" ]; then
	# -t 分割間隔秒
	if [ "$#" -lt 3 ]; then
		echo "Usage:"
		echo "   $0 -t <split_duration_sec> <video_file> [ <video_file> ... ]"
		exit 1
	fi
	# 半角数値のみ（整数のみ）
	if [[ ! "$2" =~ ^[0-9]+$ ]]; then
		echo "Usage:"
		echo "   $0 -c <split_duration_sec> <video_file> [ <video_file> ... ]"
		echo "         --> split_duration_sec accept only integer"
		exit 1
	fi
	SPLIT_DURATION="$2"
	# 引数２つぶんを捨てる
	shift
	shift
fi


# 動画ファイルを一つずつ処理
for I; do
	if [[ -f "$I" ]]; then
		# 通常ファイルのときのみ処理
		INPUT_FILE="$I"
		echo "ファイル名: $INPUT_FILE"

		# 動画の総時間を取得 (秒)
		DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
		# 整数化
		DURATION_INT=$(printf "%.0f" $DURATION)

		if [ $DURATION_INT -gt 0 ]; then
			# 動画であれば実施

			# 分割数と分割間隔をコピー
			SPLIT_CNT_=$SPLIT_CNT
			SPLIT_DURATION_=$SPLIT_DURATION
			# 出力ディレクトリを作成
			FILENAME=$(basename -- "$INPUT_FILE")
			FILENAME_NO_EXT="${FILENAME%.*}"
			OUTPUT_DIR="frames_$FILENAME_NO_EXT"

			# 出力ディレクトリ作成
			mkdir -p "$OUTPUT_DIR"

			# 分割間隔が指定されていれば、分割数を算出
			if [ $SPLIT_DURATION_ -gt 0 ]; then
				SPLIT_CNT_=$(echo "$DURATION / $SPLIT_DURATION_" | bc -l)
				# 整数化
				SPLIT_CNT_=$(printf "%.0f" $SPLIT_CNT_)
			fi
			# 分割数が１未満ならここで決める
			if [ $SPLIT_CNT_ -lt 1 ]; then
				if [ $DURATION_INT -lt $DEFAULT_MIN_CNT ]; then
					SPLIT_CNT_=$DURATION_INT
				else
					SPLIT_CNT_=$(( $DURATION_INT / $DEFAULT_DURATION_SEC ))
					if [ $SPLIT_CNT_ -lt $DEFAULT_MIN_CNT ]; then
						SPLIT_CNT_=$DEFAULT_MIN_CNT
					fi
				fi
			fi

			# 必要枚数を保存するための分割間隔を再計算
			# 0秒目からではなく、均等に配置するため少しずらす
			SPLIT_DURATION_=$(echo "$DURATION / ($SPLIT_CNT_ + 1)" | bc -l)

			echo "動画総時間: $DURATION 秒"
			echo "抽出間隔: $SPLIT_DURATION_ 秒"
			echo "抽出数: $SPLIT_CNT_ 枚"
			echo "保存先: $OUTPUT_DIR/"

			# 抽出数のぶんループして画像を保存
			for i in $(seq 1 $SPLIT_CNT_); do
				# 現在のタイムスタンプを計算
				TIMESTAMP=$(echo "$SPLIT_DURATION_ * $i" | bc -l)

				# ファイル名 (01, 02...)
				OUTPUT_FILE=$(printf "%s/%s_%03d.jpg" "$OUTPUT_DIR" "$FILENAME_NO_EXT" "$i")

				# ffmpegでサムネイル抽出
				# -ss: 時間指定
				# -i: 入力ファイル
				# -frames:v 1: 1フレームだけ出力
				# -q:v 2: 高画質JPEG
				ffmpeg -ss "$TIMESTAMP" -i "$INPUT_FILE" -frames:v 1 -q:v 2 -y "$OUTPUT_FILE" -loglevel error

				echo "Generated: $OUTPUT_FILE ($TIMESTAMP s)"
			done
		fi
	fi
done

echo "完了しました。"
