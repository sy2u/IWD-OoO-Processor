interface dmem_itf();

    logic   [31:0]  addr;
    logic   [3:0]   rmask;
    logic   [3:0]   wmask;
    logic   [31:0]  rdata;
    logic   [31:0]  wdata;
    logic           resp;

    modport cpu (
        output              addr,
        output              rmask,
        output              wmask,
        input               rdata,
        output              wdata,
        input               resp
    );

    modport cache (
        input               addr,
        input               rmask,
        input               wmask,
        output              rdata,
        input               wdata,
        output              resp
    );

endinterface

interface dmem_wo_itf();

    logic   [31:0]  addr;
    logic   [3:0]   wmask;
    logic   [31:0]  wdata;
    logic           resp;

    modport cpu (
        output              addr,
        output              wmask,
        output              wdata,
        input               resp
    );

    modport cache (
        input               addr,
        input               wmask,
        input               wdata,
        output              resp
    );

endinterface

interface dmem_ro_itf();

    logic   [31:0]  addr;
    logic   [3:0]   rmask;
    logic   [31:0]  rdata;
    logic           resp;

    modport cpu (
        output              addr,
        output              rmask,
        input               rdata,
        input               resp
    );

    modport cache (
        input               addr,
        input               rmask,
        output              rdata,
        output              resp
    );

endinterface
