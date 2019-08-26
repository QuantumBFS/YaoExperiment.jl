from pyquil.quilbase import *
from pyquil.gates import QUANTUM_GATES
from quil_run import quil_run

class MeasurementReset(AbstractInstruction):
    """
    This is the pyQuil object for a Quil measurement instruction.
    """

    def __init__(self, qubit, classical_reg):
        if not isinstance(qubit, (Qubit, QubitPlaceholder)):
            raise TypeError("qubit should be a Qubit")
        if classical_reg and not isinstance(classical_reg, MemoryReference):
            raise TypeError("classical_reg should be None or a MemoryReference instance")

        self.qubit = qubit
        self.classical_reg = classical_reg

    def out(self):
        if self.classical_reg:
            return "MEASURE_RESET {} {}".format(self.qubit.out(), self.classical_reg.out())
        else:
            return "MEASURE_RESET {}".format(self.qubit.out())

    def __str__(self):
        if self.classical_reg:
            return "MEASURE_RESET {} {}".format(_format_qubit_str(self.qubit), str(self.classical_reg))
        else:
            return "MEASURE_RESET {}".format(_format_qubit_str(self.qubit))

    def get_qubits(self, indices=True):
        return {_extract_qubit_index(self.qubit, indices)}

def MEASURE_RESET(qubit, classical_reg):
    """
    Produce a MEASURE_RESET instruction.
    :param qubit: The qubit to measure.
    :param classical_reg: The classical register to measure into, or None.
    :return: A Measurement instance.
    """
    print("@@@@")
    qubit = unpack_qubit(qubit)
    if classical_reg is None:
        address = None
    elif isinstance(classical_reg, int):
        warn("Indexing measurement addresses by integers is deprecated. "
             + "Replacing this with the MemoryReference ro[i] instead.")
        address = MemoryReference("ro", classical_reg)
    else:
        address = unpack_classical_reg(classical_reg)
    return MeasurementReset(qubit, address)

QUANTUM_GATES['MEASURE_RESET'] = MEASURE_RESET

if __name__ == "__main__":
    quil_run("MEASURE 0 ro[0]")
