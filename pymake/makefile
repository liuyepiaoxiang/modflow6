# makefile created on 2021-10-12 16:13:16.130574
# by pymake (version 1.2.1) for the 'mf6' executable 
# using the 'gfortran' fortran compiler(s).


include ./makedefaults

# Define the source file directories
SOURCEDIR1=../src
SOURCEDIR2=../src/Exchange
SOURCEDIR3=../src/Solution
SOURCEDIR4=../src/Solution/SparseMatrixSolver
SOURCEDIR5=../src/Timing
SOURCEDIR6=../src/Utilities
SOURCEDIR7=../src/Utilities/TimeSeries
SOURCEDIR8=../src/Utilities/Memory
SOURCEDIR9=../src/Utilities/OutputControl
SOURCEDIR10=../src/Utilities/Observation
SOURCEDIR11=../src/Model
SOURCEDIR12=../src/Model/GroundWaterTransport
SOURCEDIR13=../src/Model/ModelUtilities
SOURCEDIR14=../src/Model/GroundWaterFlow
SOURCEDIR15=../src/Model/Geometry

VPATH = \
${SOURCEDIR1} \
${SOURCEDIR2} \
${SOURCEDIR3} \
${SOURCEDIR4} \
${SOURCEDIR5} \
${SOURCEDIR6} \
${SOURCEDIR7} \
${SOURCEDIR8} \
${SOURCEDIR9} \
${SOURCEDIR10} \
${SOURCEDIR11} \
${SOURCEDIR12} \
${SOURCEDIR13} \
${SOURCEDIR14} \
${SOURCEDIR15} 

.SUFFIXES: .f90 .F90 .o

OBJECTS = \
$(OBJDIR)/OpenSpec.o \
$(OBJDIR)/kind.o \
$(OBJDIR)/HashTable.o \
$(OBJDIR)/compilerversion.o \
$(OBJDIR)/Constants.o \
$(OBJDIR)/BaseGeometry.o \
$(OBJDIR)/SimVariables.o \
$(OBJDIR)/GwfNpfOptions.o \
$(OBJDIR)/ims8reordering.o \
$(OBJDIR)/Sparse.o \
$(OBJDIR)/GwfNpfGridData.o \
$(OBJDIR)/PackageBudget.o \
$(OBJDIR)/GwfStorageUtils.o \
$(OBJDIR)/genericutils.o \
$(OBJDIR)/defmacro.o \
$(OBJDIR)/ims8sparsekit.o \
$(OBJDIR)/ArrayHandlers.o \
$(OBJDIR)/Xt3dAlgorithm.o \
$(OBJDIR)/version.o \
$(OBJDIR)/SfrCrossSectionUtils.o \
$(OBJDIR)/SmoothingFunctions.o \
$(OBJDIR)/List.o \
$(OBJDIR)/Timer.o \
$(OBJDIR)/StringList.o \
$(OBJDIR)/TimeSeriesRecord.o \
$(OBJDIR)/mf6lists.o \
$(OBJDIR)/Message.o \
$(OBJDIR)/ObsOutput.o \
$(OBJDIR)/Sim.o \
$(OBJDIR)/sort.o \
$(OBJDIR)/Budget.o \
$(OBJDIR)/InputOutput.o \
$(OBJDIR)/RectangularGeometry.o \
$(OBJDIR)/BlockParser.o \
$(OBJDIR)/Iunit.o \
$(OBJDIR)/MemoryHelper.o \
$(OBJDIR)/NameFile.o \
$(OBJDIR)/ArrayReaders.o \
$(OBJDIR)/comarg.o \
$(OBJDIR)/SfrCrossSectionManager.o \
$(OBJDIR)/ObsOutputList.o \
$(OBJDIR)/HeadFileReader.o \
$(OBJDIR)/DisvGeom.o \
$(OBJDIR)/BudgetFileReader.o \
$(OBJDIR)/TableTerm.o \
$(OBJDIR)/CircularGeometry.o \
$(OBJDIR)/TimeSeries.o \
$(OBJDIR)/PrintSaveManager.o \
$(OBJDIR)/ims8base.o \
$(OBJDIR)/TimeSeriesLink.o \
$(OBJDIR)/Table.o \
$(OBJDIR)/ListReader.o \
$(OBJDIR)/TimeSeriesFileList.o \
$(OBJDIR)/Memory.o \
$(OBJDIR)/MemoryList.o \
$(OBJDIR)/MemoryManager.o \
$(OBJDIR)/ats.o \
$(OBJDIR)/BaseModel.o \
$(OBJDIR)/PackageMover.o \
$(OBJDIR)/tdis.o \
$(OBJDIR)/ims8linear.o \
$(OBJDIR)/Connections.o \
$(OBJDIR)/MemorySetHandler.o \
$(OBJDIR)/Mover.o \
$(OBJDIR)/TimeSeriesManager.o \
$(OBJDIR)/UzfCellGroup.o \
$(OBJDIR)/BaseExchange.o \
$(OBJDIR)/DiscretizationBase.o \
$(OBJDIR)/gwf3dis8.o \
$(OBJDIR)/BudgetTerm.o \
$(OBJDIR)/Observe.o \
$(OBJDIR)/gwf3disu8.o \
$(OBJDIR)/BaseSolution.o \
$(OBJDIR)/gwf3disv8.o \
$(OBJDIR)/Xt3dInterface.o \
$(OBJDIR)/BudgetObject.o \
$(OBJDIR)/TimeArray.o \
$(OBJDIR)/NumericalPackage.o \
$(OBJDIR)/OutputControlData.o \
$(OBJDIR)/ObsContainer.o \
$(OBJDIR)/ObsUtility.o \
$(OBJDIR)/gwf3mvr8.o \
$(OBJDIR)/gwf3hfb8.o \
$(OBJDIR)/SolutionGroup.o \
$(OBJDIR)/TimeArraySeries.o \
$(OBJDIR)/gwf3ic8.o \
$(OBJDIR)/Obs3.o \
$(OBJDIR)/OutputControl.o \
$(OBJDIR)/gwf3tvbase8.o \
$(OBJDIR)/TimeArraySeriesLink.o \
$(OBJDIR)/gwf3csub8.o \
$(OBJDIR)/gwt1oc1.o \
$(OBJDIR)/gwt1ic1.o \
$(OBJDIR)/gwt1obs1.o \
$(OBJDIR)/TimeArraySeriesManager.o \
$(OBJDIR)/gwf3tvk8.o \
$(OBJDIR)/gwf3obs8.o \
$(OBJDIR)/gwf3npf8.o \
$(OBJDIR)/GwtSpc.o \
$(OBJDIR)/gwf3tvs8.o \
$(OBJDIR)/BoundaryPackage.o \
$(OBJDIR)/gwf3oc8.o \
$(OBJDIR)/gwf3lak8.o \
$(OBJDIR)/gwf3riv8.o \
$(OBJDIR)/gwf3drn8.o \
$(OBJDIR)/gwf3ghb8.o \
$(OBJDIR)/gwt1cnc1.o \
$(OBJDIR)/gwf3uzf8.o \
$(OBJDIR)/gwf3api8.o \
$(OBJDIR)/gwf3wel8.o \
$(OBJDIR)/gwf3sto8.o \
$(OBJDIR)/gwf3rch8.o \
$(OBJDIR)/gwf3maw8.o \
$(OBJDIR)/gwt1fmi1.o \
$(OBJDIR)/gwf3evt8.o \
$(OBJDIR)/gwt1src1.o \
$(OBJDIR)/gwf3chd8.o \
$(OBJDIR)/NumericalModel.o \
$(OBJDIR)/gwf3sfr8.o \
$(OBJDIR)/gwt1mvt1.o \
$(OBJDIR)/gwt1mst1.o \
$(OBJDIR)/gwt1adv1.o \
$(OBJDIR)/gwt1ist1.o \
$(OBJDIR)/gwf3buy8.o \
$(OBJDIR)/NumericalExchange.o \
$(OBJDIR)/gwt1apt1.o \
$(OBJDIR)/gwt1dsp.o \
$(OBJDIR)/gwt1uzt1.o \
$(OBJDIR)/gwt1ssm1.o \
$(OBJDIR)/GhostNode.o \
$(OBJDIR)/gwt1lkt1.o \
$(OBJDIR)/NumericalSolution.o \
$(OBJDIR)/gwt1mwt1.o \
$(OBJDIR)/DisConnExchange.o \
$(OBJDIR)/gwt1sft1.o \
$(OBJDIR)/gwf3.o \
$(OBJDIR)/GwfGwfExchange.o \
$(OBJDIR)/gwt1.o \
$(OBJDIR)/GwfGwtExchange.o \
$(OBJDIR)/SimulationCreate.o \
$(OBJDIR)/mf6core.o \
$(OBJDIR)/mf6.o

# Define the objects that make up the program
$(PROGRAM) : $(OBJECTS)
	-$(FC) $(OPTLEVEL) -o $@ $(OBJECTS) $(LDFLAGS)

$(OBJDIR)/%.o : %.f90
	@mkdir -p $(@D)
	$(FC) $(OPTLEVEL) $(FFLAGS) -c $< -o $@ $(INCSWITCH) $(MODSWITCH)

$(OBJDIR)/%.o : %.F90
	@mkdir -p $(@D)
	$(FC) $(OPTLEVEL) $(FFLAGS) -c $< -o $@ $(INCSWITCH) $(MODSWITCH)

