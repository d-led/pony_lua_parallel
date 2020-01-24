FROM ponylang/ponyc:release

ARG MAX_NUM=40
ENV MAX_NUM=${MAX_NUM}

COPY . /src/main/
WORKDIR /src/main
RUN stable env ponyc
RUN MAX_NUM=$MAX_NUM ./main --ponynoscale --ponymaxthreads=2
CMD MAX_NUM=$MAX_NUM
