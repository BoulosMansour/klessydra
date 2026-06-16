# Thesis Title

**Design-Space Exploration of Fault-Tolerance and In-Field Monitoring Techniques for the Klessydra RISC-V Vector Accelerator**

Master's thesis in Mechatronics Engineering — Politecnico di Torino

---

# Abstract

The growing deployment of RISC-V processors in safety- and mission-critical domains — automotive, aerospace, and edge AI — demands hardware that can tolerate and detect faults induced by radiation, ageing, and environmental stress. Vector accelerators, which dominate both the silicon area and the computational workload of modern embedded cores, are particularly exposed. This thesis investigates the design and characterization of fault-tolerance and in-field monitoring mechanisms for the SIMD vector accelerator of the Klessydra RISC-V architecture.

The work begins by re-engineering the originally monolithic VHDL accelerator into a modular, hierarchical design in which each functional unit — adders, multipliers, shifters, comparators, and accumulator — is cleanly isolated, enabling fault-tolerance mechanisms to be inserted at fine granularity. On this basis, reusable Dual Modular Redundancy (DMR), providing error detection through an error flag, and Triple Modular Redundancy (TMR), providing error masking through majority voting, are developed and applied both selectively to individual functional units and globally to the complete accelerator. This produces a family of hardened configurations spanning a wide range of protection-versus-cost trade-offs.

To complement the structural redundancy with run-time observability, an automated tool is developed that injects IEEE 1687 (IJTAG) sensors — including thermal and activity monitors — directly into the VHDL hierarchy and generates the corresponding Tessent scripts to build the on-chip IJTAG access network, allowing in-field health monitoring without manual rewiring of the design.

All configurations are functionally verified through simulation and synthesized across multiple technology nodes spanning a mature, a mainstream, and an advanced process, yielding a comprehensive characterization of the area, power, and timing overhead of each redundancy scheme at both the functional-unit and the full-accelerator level. The results quantify the cost of protection — showing that duplication-based detection and triplication-based masking incur consistent and predictable area and power penalties across nodes, while the choice of which functional unit to harden dominates the overall cost — and provide design guidelines for selecting the appropriate fault-tolerance strategy under given reliability and resource constraints. The study further shows that, when an accelerator is already replicated for throughput, adding voting-based redundancy comes at a comparatively small marginal cost. Overall, the proposed flow demonstrates a reusable, automatable methodology for hardening RISC-V vector accelerators against faults while keeping them observable in the field.
