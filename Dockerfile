FROM ponylang/ponyc:release

ARG MAX_NUM=40
ENV MAX_NUM=${MAX_NUM}

COPY . /src/main/
WORKDIR /src/main
RUN corral run -- ponyc
RUN MAX_NUM=$MAX_NUM ./main
CMD MAX_NUM=$MAX_NUM ./main
