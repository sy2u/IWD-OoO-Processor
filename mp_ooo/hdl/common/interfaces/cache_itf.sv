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

interface stq_dmem_itf();

    logic           valid;
    logic           ready;
    logic   [31:0]  addr;
    logic   [3:0]   wmask;
    logic   [31:0]  wdata;
    logic           resp;

    modport stq (
        output              valid,
        input               ready,
        output              addr,
        output              wmask,
        output              wdata,
        input               resp
    );

    modport cache (
        input               valid,
        output              ready,
        input               addr,
        input               wmask,
        input               wdata,
        output              resp
    );

endinterface

interface ldq_dmem_itf();

    logic           valid;
    logic           ready;
    logic   [31:0]  addr;
    logic   [3:0]   rmask;

    logic           resp;
    logic   [31:0]  rdata;

    modport ldq (
        output              valid,
        input               ready,
        output              addr,
        output              rmask,
        input               resp,
        input               rdata
    );

    modport cache (
        input               valid,
        output              ready,
        input               addr,
        input               rmask,
        output              resp,
        output              rdata
    );

endinterface
