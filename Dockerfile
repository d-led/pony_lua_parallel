FROM ponylang/ponyc:release

COPY . /src/main/
WORKDIR /src/main
RUN stable env ponyc
RUN ./main
CMD ./main
