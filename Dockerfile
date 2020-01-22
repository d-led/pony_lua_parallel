FROM ponylang/ponyc:release

COPY . /src/main/
WORKDIR /src/main/test
RUN stable env ponyc
RUN ./test
CMD ./test
