/* P4-16 In-band Network Telemetry (INT) Demo */
#include <core.p4>
#include <v1model.p4>

/* -------------------------------------------------------------------------
   HEADERS
   ------------------------------------------------------------------------- */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header telemetry_t {
    bit<32> switch_id;
    bit<16> q_depth;
    bit<16> next_proto; // Original protocol (TCP/UDP)
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    telemetry_t  telemetry;
}

struct metadata {
    /* Empty - we don't need custom metadata for this simple demo */
}

/* -------------------------------------------------------------------------
   PARSER
   ------------------------------------------------------------------------- */
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            0x99: parse_telemetry; // 0x99 = Our Custom Protocol ID
            default: accept;
        }
    }

    state parse_telemetry {
        packet.extract(hdr.telemetry);
        transition accept;
    }
}

/* -------------------------------------------------------------------------
   INGRESS PROCESSING
   ------------------------------------------------------------------------- */
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* Action: Standard L3 Forwarding */
    action ipv4_forward(bit<48> dstAddr, bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    /* Action: Drop */
    action drop() {
        mark_to_drop(standard_metadata);
    }

    /* Table: Longest Prefix Match (LPM) Routing */
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
    }
}

/* -------------------------------------------------------------------------
   EGRESS PROCESSING (The Telemetry Logic)
   ------------------------------------------------------------------------- */
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {
        // If this is a telemetry packet, record the queue depth
        if (hdr.telemetry.isValid()) {
            hdr.telemetry.q_depth = (bit<16>)standard_metadata.enq_qdepth;
            hdr.telemetry.switch_id = 1; // Hardcoded ID for this switch
        }
    }
}

/* -------------------------------------------------------------------------
   DEPARSER
   ------------------------------------------------------------------------- */
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.telemetry);
    }
}

/* -------------------------------------------------------------------------
   Checksums (Boilerplate - Required for compilation)
   ------------------------------------------------------------------------- */
control MyVerifyChecksum(inout headers hdr, inout metadata meta) { apply { } }
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            {
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.totalLen,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.fragOffset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.srcAddr,
                hdr.ipv4.dstAddr
            },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16
        );
    }
}
/* -------------------------------------------------------------------------
   SWITCH INSTANTIATION
   ------------------------------------------------------------------------- */
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
