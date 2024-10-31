interface cacheline_itf();

    logic   [31:0]          addr;
    logic                   read;
    logic                   write;
    logic   [255:0]         wdata;
    logic                   ready;
    logic   [31:0]          raddr;
    logic   [255:0]         rdata;
    logic                   rvalid;

    modport master (
        output              addr,
        output              read,
        output              write,
        output              wdata,
        input               ready,
        input               raddr,
        input               rdata,
        input               rvalid
    );

    modport slave (
        input               addr,
        input               read,
        input               write,
        input               wdata,
        output              ready,
        output              rdata,
        output              raddr,
        output              rvalid
    );

endinterface
