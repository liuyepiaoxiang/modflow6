! This is the numerical solution module.

module NumericalSolutionModule
  use KindModule,              only: DP, I4B
  use TimerModule,             only: code_timer
  use ConstantsModule,         only: LINELENGTH, LENSOLUTIONNAME, LENPAKLOC,   &
                                     DPREC, DZERO, DEM20, DEM15, DEM6,         &
                                     DEM4, DEM3, DEM2, DEM1, DHALF, DONETHIRD, &
                                     DONE, DTHREE, DEP3, DEP6, DEP20, DNODATA, &
                                     TABLEFT, TABRIGHT,                        &
                                     MNORMAL, MVALIDATE,                       &
                                     LENMEMPATH
  use MemoryHelperModule,      only: create_mem_path                                     
  use TableModule,             only: TableType, table_cr
  use GenericUtilitiesModule,  only: is_same, sim_message, stop_with_error
  use VersionModule,           only: IDEVELOPMODE
  use BaseModelModule,         only: BaseModelType
  use BaseExchangeModule,      only: BaseExchangeType
  use BaseSolutionModule,      only: BaseSolutionType, AddBaseSolutionToList
  use ListModule,              only: ListType
  use ListsModule,             only: basesolutionlist
  use NumericalModelModule,    only: NumericalModelType,                       &
                                     AddNumericalModelToList,                  &
                                     GetNumericalModelFromList
  use NumericalExchangeModule, only: NumericalExchangeType,                    &
                                     AddNumericalExchangeToList,               &
                                     GetNumericalExchangeFromList
  use SparseModule,            only: sparsematrix
  use SimVariablesModule,      only: iout, isim_mode
  use BlockParserModule,       only: BlockParserType
  use IMSLinearModule

  implicit none
  private
  
  public :: solution_create
  public :: NumericalSolutionType
  public :: GetNumericalSolutionFromList
  
  type, extends(BaseSolutionType) :: NumericalSolutionType
    character(len=LENMEMPATH)                        :: memoryPath        !< the path for storing solution variables in the memory manager
    character(len=LINELENGTH)                        :: fname             !< input file name
    type(ListType), pointer                          :: modellist         !< list of models in solution
    type(ListType), pointer                          :: exchangelist      !< list of exchanges in solution
    integer(I4B), pointer                            :: id                !< solution number
    integer(I4B), pointer                            :: iu                !< input file unit
    real(DP), pointer                                :: ttform            !< timer - total formulation time
    real(DP), pointer                                :: ttsoln            !< timer - total solution time
    integer(I4B), pointer                            :: neq => null()     !< number of equations
    integer(I4B), pointer                            :: nja => null()     !< number of non-zero entries
    integer(I4B), dimension(:), pointer, contiguous  :: ia => null()      !< CRS row pointers
    integer(I4B), dimension(:), pointer, contiguous  :: ja => null()      !< CRS column pointers
    real(DP), dimension(:), pointer, contiguous      :: amat => null()    !< coefficient matrix
    real(DP), dimension(:), pointer, contiguous      :: rhs => null()     !< right-hand side vector
    real(DP), dimension(:), pointer, contiguous      :: x => null()       !< dependent-variable vector
    integer(I4B), dimension(:), pointer, contiguous  :: active => null()  !< active cell array
    real(DP), dimension(:), pointer, contiguous      :: xtemp => null()   !< temporary vector for previous dependent-variable iterate
    type(BlockParserType) :: parser                                       !< block parser object
    !
    ! -- sparse matrix data
    real(DP), pointer                                :: theta => null()            !< under-relaxation theta
    real(DP), pointer                                :: akappa => null()           !< under-relaxation kappa
    real(DP), pointer                                :: gamma => null()            !< under-relaxation gamma
    real(DP), pointer                                :: amomentum => null()        !< under-relaxation momentum term
    real(DP), pointer                                :: breduc => null()           !< backtracking reduction factor
    real(DP), pointer                                :: btol => null()             !< backtracking tolerance
    real(DP), pointer                                :: res_lim => null()          !< backtracking residual threshold
    real(DP), pointer                                :: dvclose => null()          !< dependent-variable closure criteria
    real(DP), pointer                                :: bigchold => null()         !< cooley under-relaxation weight
    real(DP), pointer                                :: bigch => null()            !< under-relaxation maximum dependent-variable change
    real(DP), pointer                                :: relaxold => null()         !< under-relaxation previous relaxation factor
    real(DP), pointer                                :: res_prev => null()         !< previous L-2 norm
    real(DP), pointer                                :: res_new => null()          !< current L-2 norm
    integer(I4B), pointer                            :: icnvg => null()            !< convergence flag (1) non-convergence (0)
    integer(I4B), pointer                            :: itertot_timestep => null() !< total nr. of linear solves per call to sln_ca
    integer(I4B), pointer                            :: iouttot_timestep => null() !< total nr. of outer iterations per call to sln_ca
    integer(I4B), pointer                            :: itertot_sim => null()      !< total nr. of inner iterations for simulation
    integer(I4B), pointer                            :: mxiter => null()           !< maximum number of Picard iterations
    integer(I4B), pointer                            :: linmeth => null()          !< linear acceleration method used
    integer(I4B), pointer                            :: nonmeth => null()          !< under-relaxation method used
    integer(I4B), pointer                            :: numtrack => null()         !< maximum number of backtracks
    integer(I4B), pointer                            :: iprims => null()           !< solver print option
    integer(I4B), pointer                            :: ibflag => null()           !< backtracking flag (1) on (0) off
    integer(I4B), dimension(:,:), pointer, contiguous:: lrch => null()             !< location of the largest dependent-variable change at the end of a Picard iteration
    real(DP), dimension(:), pointer, contiguous      :: hncg => null()             !< largest dependent-variable change at the end of a Picard iteration
    real(DP), dimension(:), pointer, contiguous      :: dxold => null()            !< DBD under-relaxation previous dependent-variable change
    real(DP), dimension(:), pointer, contiguous      :: deold => null()            !< DBD under-relaxation dependent-variable change variable
    real(DP), dimension(:), pointer, contiguous      :: wsave => null()            !< DBD under-relaxation sign-change factor
    real(DP), dimension(:), pointer, contiguous      :: hchold => null()           !< DBD under-relaxation weighted dependent-variable change
    !
    ! -- convergence summary information
    character(len=31), dimension(:), pointer, contiguous :: caccel => null()               !< convergence string
    integer(I4B), pointer                                :: icsvouterout => null()         !< Picard iteration CSV output flag and file unit 
    integer(I4B), pointer                                :: icsvinnerout => null()         !< Inner iteration CSV output flag and file unit
    integer(I4B), pointer                                :: nitermax => null()             !< maximum number of iterations in a time step (maxiter * maxinner)
    integer(I4B), pointer                                :: convnmod => null()             !< number of models in the solution
    integer(I4B), dimension(:), pointer, contiguous      :: convmodstart => null()         !< pointer to the start of each model in the convmod* arrays
    integer(I4B), dimension(:), pointer, contiguous      :: locdv => null()                !< location of the maximum dependent-variable change in the solution
    integer(I4B), dimension(:), pointer, contiguous      :: locdr => null()                !< location of the maximum flow change in the solution
    integer(I4B), dimension(:), pointer, contiguous      :: itinner => null()              !< actual number of inner iterations in each Picard iteration
    integer(I4B), pointer, dimension(:,:), contiguous    :: convlocdv => null()            !< location of the maximum dependent-variable change in each model in the solution
    integer(I4B), pointer, dimension(:,:), contiguous    :: convlocdr => null()            !< location of the maximum flow change in each model in the solution
    real(DP), dimension(:), pointer, contiguous          :: dvmax => null()                !< maximum dependent-variable change in the solution
    real(DP), dimension(:), pointer, contiguous          :: drmax => null()                !< maximum flow change in the solution
    real(DP), pointer, dimension(:,:), contiguous        :: convdvmax => null()            !< maximum dependent-variable change in each model in the solution
    real(DP), pointer, dimension(:,:), contiguous        :: convdrmax => null()            !< maximum flow change in each model in the solution
    !
    ! -- pseudo-transient continuation
    integer(I4B), pointer                                :: iallowptc => null()            !< flag indicating if ptc applied this time step
    integer(I4B), pointer                                :: iptcopt => null()              !< option for how to calculate the initial PTC value (ptcdel0)
    integer(I4B), pointer                                :: iptcout => null()              !< PTC output flag and file unit 
    real(DP), pointer                                    :: l2norm0 => null()              !< L-2 norm at the start of the first Picard iteration
    real(DP), pointer                                    :: ptcdel => null()               !< PTC delta value
    real(DP), pointer                                    :: ptcdel0 => null()              !< initial PTC delta value
    real(DP), pointer                                    :: ptcexp => null()               !< PTC exponent
    real(DP), pointer                                    :: ptcthresh => null()            !< PTC threshold value (0.001)
    real(DP), pointer                                    :: ptcrat => null()               !< ratio of the PTC value and the minimum of the diagonal of AMAT used to determine if the PTC effect has decayed 
    !
    ! -- adaptive time step
    real(DP), pointer                                    :: atsfrac => null()              !< adaptive time step faction
    !
    ! -- linear accelerator storage
    type(ImsLinearDataType), pointer                     :: imslinear => null()            !< IMS linear acceleration object
    !
    ! -- sparse object
    type(sparsematrix)                                   :: sparse                         !< sparse object
    !
    ! -- table objects
    type(TableType), pointer :: innertab => null()                                         !< inner iteration table object
    type(TableType), pointer :: outertab => null()                                         !< Picard iteration table object

  contains
    procedure :: sln_df
    procedure :: sln_ar
    procedure :: sln_calculate_delt
    procedure :: sln_ad
    procedure :: sln_ot
    procedure :: sln_ca
    procedure :: sln_fp
    procedure :: sln_da
    procedure :: add_model
    procedure :: add_exchange
    procedure :: get_models
    procedure :: get_exchanges
    procedure :: save

    procedure, private :: sln_connect
    procedure, private :: sln_reset
    procedure, private :: sln_ls
    procedure, private :: sln_setouter
    procedure, private :: sln_backtracking
    procedure, private :: sln_backtracking_xupdate
    procedure, private :: sln_l2norm
    procedure, private :: sln_maxval
    procedure, private :: sln_calcdx
    procedure, private :: sln_underrelax
    procedure, private :: sln_outer_check
    procedure, private :: sln_get_loc
    procedure, private :: sln_get_nodeu
    procedure, private :: allocate_scalars
    procedure, private :: allocate_arrays
    procedure, private :: convergence_summary
    procedure, private :: csv_convergence_summary
    procedure, private :: sln_buildsystem
    procedure, private :: writeCSVHeader
    procedure, private :: writePTCInfoToFile
    
    ! Expose these for use through the BMI/XMI:
    procedure, public :: prepareSolve
    procedure, public :: solve
    procedure, public :: finalizeSolve
  
  end type NumericalSolutionType

contains

!> @ brief Create a new solution
!!
!!  Create a new solution using the data in filename, assign this new 
!!  solution an id number and store the solution in the basesolutionlist.
!!  Also open the filename for later reading.
!!
!<
subroutine solution_create(filename, id)
    ! -- modules
    use SimVariablesModule, only: iout
    use InputOutputModule,  only: getunit, openfile
    ! -- dummy variables
    character(len=*),intent(in) :: filename    !< solution input file name
    integer(I4B),intent(in) :: id              !< solution id
    ! -- local variables
    integer(I4B) :: inunit
    type(NumericalSolutionType), pointer :: solution => null()
    class(BaseSolutionType), pointer :: solbase => null()
    character(len=LENSOLUTIONNAME) :: solutionname
    !
    ! -- Create a new solution and add it to the basesolutionlist container
    allocate(solution)
    solbase => solution
    write(solutionname,'(a, i0)') 'SLN_', id
    !
    solution%name = solutionname
    solution%memoryPath = create_mem_path(solutionname)
    allocate(solution%modellist)
    allocate(solution%exchangelist)
    !
    call solution%allocate_scalars()
    !
    call AddBaseSolutionToList(basesolutionlist, solbase)
    !
    solution%id = id
    !
    ! -- Open solution input file for reading later after problem size is known
    !    Check to see if the file is already opened, which can happen when
    !    running in single model mode
    inquire(file=filename, number=inunit)

    if(inunit < 0) inunit = getunit()
    solution%iu = inunit
    write(iout,'(/a,a)') ' Creating solution: ', solution%name
    call openfile(solution%iu, iout, filename, 'IMS')
    !
    ! -- Initialize block parser
    call solution%parser%Initialize(solution%iu, iout)
    !
    ! -- return
    return
  end subroutine solution_create

  !> @ brief Allocate scalars
  !!
  !!  Allocate scalars for a new solution.
  !!
  !<
  subroutine allocate_scalars(this)
    ! -- modules
    use MemoryManagerModule, only: mem_allocate
    ! -- dummy variables
    class(NumericalSolutionType) :: this
    !
    ! -- allocate scalars
    call mem_allocate(this%id, 'ID', this%memoryPath)
    call mem_allocate(this%iu, 'IU', this%memoryPath)
    call mem_allocate(this%ttform, 'TTFORM', this%memoryPath)
    call mem_allocate(this%ttsoln, 'TTSOLN', this%memoryPath)
    call mem_allocate(this%neq, 'NEQ', this%memoryPath)
    call mem_allocate(this%nja, 'NJA', this%memoryPath)
    call mem_allocate(this%dvclose, 'DVCLOSE', this%memoryPath)
    call mem_allocate(this%bigchold, 'BIGCHOLD', this%memoryPath)
    call mem_allocate(this%bigch, 'BIGCH', this%memoryPath)
    call mem_allocate(this%relaxold, 'RELAXOLD', this%memoryPath)
    call mem_allocate(this%res_prev, 'RES_PREV', this%memoryPath)
    call mem_allocate(this%res_new, 'RES_NEW', this%memoryPath)
    call mem_allocate(this%icnvg, 'ICNVG', this%memoryPath)
    call mem_allocate(this%itertot_timestep, 'ITERTOT_TIMESTEP', this%memoryPath)
    call mem_allocate(this%iouttot_timestep, 'IOUTTOT_TIMESTEP', this%memoryPath)
    call mem_allocate(this%itertot_sim, 'INNERTOT_SIM', this%memoryPath)
    call mem_allocate(this%mxiter, 'MXITER', this%memoryPath)
    call mem_allocate(this%linmeth, 'LINMETH', this%memoryPath)
    call mem_allocate(this%nonmeth, 'NONMETH', this%memoryPath)
    call mem_allocate(this%iprims, 'IPRIMS', this%memoryPath)
    call mem_allocate(this%theta, 'THETA', this%memoryPath)
    call mem_allocate(this%akappa, 'AKAPPA', this%memoryPath)
    call mem_allocate(this%gamma, 'GAMMA', this%memoryPath)
    call mem_allocate(this%amomentum, 'AMOMENTUM', this%memoryPath)
    call mem_allocate(this%breduc, 'BREDUC', this%memoryPath)
    call mem_allocate(this%btol, 'BTOL', this%memoryPath)
    call mem_allocate(this%res_lim, 'RES_LIM', this%memoryPath)
    call mem_allocate(this%numtrack, 'NUMTRACK', this%memoryPath)
    call mem_allocate(this%ibflag, 'IBFLAG', this%memoryPath)
    call mem_allocate(this%icsvouterout, 'ICSVOUTEROUT', this%memoryPath)
    call mem_allocate(this%icsvinnerout, 'ICSVINNEROUT', this%memoryPath)
    call mem_allocate(this%nitermax, 'NITERMAX', this%memoryPath)
    call mem_allocate(this%convnmod, 'CONVNMOD', this%memoryPath)
    call mem_allocate(this%iallowptc, 'IALLOWPTC', this%memoryPath) 
    call mem_allocate(this%iptcopt, 'IPTCOPT', this%memoryPath)
    call mem_allocate(this%iptcout, 'IPTCOUT', this%memoryPath)
    call mem_allocate(this%l2norm0, 'L2NORM0', this%memoryPath)
    call mem_allocate(this%ptcdel, 'PTCDEL', this%memoryPath)
    call mem_allocate(this%ptcdel0, 'PTCDEL0', this%memoryPath)
    call mem_allocate(this%ptcexp, 'PTCEXP', this%memoryPath)
    call mem_allocate(this%ptcthresh, 'PTCTHRESH', this%memoryPath)
    call mem_allocate(this%ptcrat, 'PTCRAT', this%memoryPath)
    call mem_allocate(this%atsfrac, 'ATSFRAC', this%memoryPath)
    !
    ! -- initialize scalars
    this%id = 0
    this%iu = 0
    this%ttform = DZERO
    this%ttsoln = DZERO
    this%neq = 0
    this%nja = 0
    this%dvclose = DZERO
    this%bigchold = DZERO
    this%bigch = DZERO
    this%relaxold = DZERO
    this%res_prev = DZERO
    this%icnvg = 0
    this%itertot_timestep = 0
    this%iouttot_timestep = 0
    this%itertot_sim = 0
    this%mxiter = 0
    this%linmeth = 1
    this%nonmeth = 0
    this%iprims = 0
    this%theta = DONE
    this%akappa = DZERO
    this%gamma = DONE
    this%amomentum = DZERO
    this%breduc = DZERO
    this%btol = 0
    this%res_lim = DZERO
    this%numtrack = 0
    this%ibflag = 0
    this%icsvouterout = 0
    this%icsvinnerout = 0
    this%nitermax = 0
    this%convnmod = 0
    this%iallowptc = 1
    this%iptcopt = 0
    this%iptcout = 0
    this%l2norm0 = DZERO
    this%ptcdel = DZERO
    this%ptcdel0 = DZERO
    this%ptcexp = done
    this%ptcthresh = DEM3
    this%ptcrat = DZERO
    this%atsfrac = DONETHIRD
    !
    ! -- return
    return
  end subroutine allocate_scalars

  !> @ brief Allocate arrays
  !!
  !!  Allocate arrays for a new solution.
  !!
  !<
  subroutine allocate_arrays(this)
    ! -- modules
    use MemoryManagerModule, only: mem_allocate
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    ! -- local variables
    class(NumericalModelType), pointer :: mp => null()
    integer(I4B) :: i
    integer(I4B) :: ieq
    !
    ! -- initialize the number of models in the solution
    this%convnmod = this%modellist%Count()
    !
    ! -- allocate arrays
    call mem_allocate(this%ia, this%neq + 1, 'IA', this%memoryPath)
    call mem_allocate(this%x, this%neq, 'X', this%memoryPath)
    call mem_allocate(this%rhs, this%neq, 'RHS', this%memoryPath)
    call mem_allocate(this%active, this%neq, 'IACTIVE', this%memoryPath)
    call mem_allocate(this%xtemp, this%neq, 'XTEMP', this%memoryPath)
    call mem_allocate(this%dxold, this%neq, 'DXOLD', this%memoryPath)
    call mem_allocate(this%hncg, 0, 'HNCG', this%memoryPath)
    call mem_allocate(this%lrch, 3, 0, 'LRCH', this%memoryPath)
    call mem_allocate(this%wsave, 0, 'WSAVE', this%memoryPath)
    call mem_allocate(this%hchold, 0, 'HCHOLD', this%memoryPath)
    call mem_allocate(this%deold, 0, 'DEOLD', this%memoryPath)
    call mem_allocate(this%convmodstart, this%convnmod+1, 'CONVMODSTART', this%memoryPath)
    call mem_allocate(this%locdv, this%convnmod, 'LOCDV', this%memoryPath)
    call mem_allocate(this%locdr, this%convnmod, 'LOCDR', this%memoryPath)
    call mem_allocate(this%itinner, 0, 'ITINNER', this%memoryPath)
    call mem_allocate(this%convlocdv, this%convnmod, 0, 'CONVLOCDV', this%memoryPath)
    call mem_allocate(this%convlocdr, this%convnmod, 0, 'CONVLOCDR', this%memoryPath)
    call mem_allocate(this%dvmax, this%convnmod, 'DVMAX', this%memoryPath)
    call mem_allocate(this%drmax, this%convnmod, 'DRMAX', this%memoryPath)
    call mem_allocate(this%convdvmax, this%convnmod, 0, 'CONVDVMAX', this%memoryPath)
    call mem_allocate(this%convdrmax, this%convnmod, 0, 'CONVDRMAX', this%memoryPath)
    !
    ! -- initialize allocated arrays
    do i = 1, this%neq
      this%x(i) = DZERO
      this%xtemp(i) = DZERO
      this%dxold(i) = DZERO
      this%active(i) = 1 !default is active
    enddo
    do i = 1, this%convnmod
      this%locdv(i) = 0
      this%locdr(i) = 0
      this%dvmax(i) = DZERO
      this%drmax(i) = DZERO
    end do
    !
    ! -- initialize convmodstart
    ieq = 1
    this%convmodstart(1) = ieq
    do i = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, i)
      ieq = ieq + mp%neq
      this%convmodstart(i+1) = ieq
    end do
    !
    ! -- return
    return
  end subroutine allocate_arrays

  !> @ brief Define the solution
  !!
  !!  Define a new solution. Must be called after the models and exchanges have 
  !!  been added to solution. The order of the steps is (1) Allocate neq and nja,
  !!  (2) Assign model offsets and solution ids, (3) Allocate and initialize 
  !!  the solution arrays, (4) Point each model's x and rhs arrays, and 
  !!  (5) Initialize the sparsematrix instance
  !!
  !<
  subroutine sln_df(this)
    ! modules
    use MemoryManagerModule, only: mem_allocate
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    ! -- local variables
    class(NumericalModelType), pointer :: mp => null()
    integer(I4B) :: i
    integer(I4B), allocatable, dimension(:) :: rowmaxnnz
    !
    ! -- calculate and set offsets
    do i = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, i)
      call mp%set_idsoln(this%id)
      call mp%set_moffset(this%neq)
      this%neq = this%neq + mp%neq
    enddo
    !
    ! -- Allocate and initialize solution arrays
    call this%allocate_arrays()
    !
    ! -- Go through each model and point x, ibound, and rhs to solution
    do i = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, i)
      call mp%set_xptr(this%x, 'X', this%name)
      call mp%set_rhsptr(this%rhs, 'RHS', this%name)
      call mp%set_iboundptr(this%active, 'IBOUND', this%name)
    enddo
    !
    ! -- Create the sparsematrix instance
    allocate(rowmaxnnz(this%neq))
    do i=1,this%neq
        rowmaxnnz(i)=4
    enddo
    call this%sparse%init(this%neq, this%neq, rowmaxnnz)
    deallocate(rowmaxnnz)
    !
    ! -- Assign connections, fill ia/ja, map connections
    call this%sln_connect()
    !
    ! -- return
    return
  end subroutine sln_df

  !> @ brief Allocate and read data
  !!
  !!  Allocate and read data for a solution.
  !!
  !<
  subroutine sln_ar(this)
    ! -- modules
    use MemoryManagerModule, only: mem_reallocate
    use SimVariablesModule, only: iout
    use SimModule, only: store_error, count_errors, deprecation_warning
    use InputOutputModule, only: getunit, openfile
    ! -- dummy variables
    class(NumericalSolutionType) :: this   !< NumericalSolutionType instance
    ! -- local variables
    class(NumericalModelType), pointer :: mp => null()
    class(NumericalExchangeType), pointer :: cp => null()
    character(len=linelength) :: errmsg
    character(len=linelength) :: warnmsg
    character(len=linelength) :: keyword
    character(len=linelength) :: fname
    character(len=linelength) :: msg
    integer(I4B) :: i
    integer(I4B) :: im
    integer(I4B) :: ifdparam, mxvl, npp
    integer(I4B) :: imslinear
    integer(I4B) :: isymflg=1
    integer(I4B) :: ierr
    logical :: isfound, endOfBlock
    integer(I4B) :: ival
    real(DP) :: rval
    character(len=*),parameter :: fmtcsvout = &
      "(4x, 'CSV OUTPUT WILL BE SAVED TO FILE: ', a, /4x, 'OPENED ON UNIT: ', I7)"
    character(len=*),parameter :: fmtptcout = &
      "(4x, 'PTC OUTPUT WILL BE SAVED TO FILE: ', a, /4x, 'OPENED ON UNIT: ', I7)"
    character(len=*), parameter :: fmterrasym = &
      "(a,' **',a,'** PRODUCES AN ASYMMETRIC COEFFICIENT MATRIX, BUT THE       &
        &CONJUGATE GRADIENT METHOD WAS SELECTED. USE BICGSTAB INSTEAD. ')"
    !
    ! identify package and initialize.
    WRITE(IOUT,1) this%iu
00001 FORMAT(1X,/1X,'IMS -- ITERATIVE MODEL SOLUTION PACKAGE, VERSION 6',      &
    &  ', 4/28/2017',/,9X,'INPUT READ FROM UNIT',I5)
    !
    ! -- initialize
    i = 1
    ifdparam = 1
    npp = 0
    mxvl = 0
    !
    ! -- get options block
    call this%parser%GetBlock('OPTIONS', isfound, ierr, &
      supportOpenClose=.true., blockRequired=.false.)
    !
    ! -- parse options block if detected
    if (isfound) then
      write(iout,'(/1x,a)')'PROCESSING IMS OPTIONS'
      do
        call this%parser%GetNextLine(endOfBlock)
        if (endOfBlock) exit
        call this%parser%GetStringCaps(keyword)
        select case (keyword)
        case ('PRINT_OPTION')
          call this%parser%GetStringCaps(keyword)
          if (keyword.eq.'NONE') then
            this%iprims = 0
          else if (keyword.eq.'SUMMARY') then
            this%iprims = 1
          else if (keyword.eq.'ALL') then
            this%iprims = 2
          else
            write(errmsg,'(3a)')                                                 &
              'UNKNOWN IMS PRINT OPTION (', trim(keyword), ').'
            call store_error(errmsg)
          end if
        case ('COMPLEXITY')
          call this%parser%GetStringCaps(keyword)
          if (keyword.eq.'SIMPLE') then
            ifdparam = 1
            WRITE(IOUT,21)
          else if (keyword.eq.'MODERATE') then
            ifdparam = 2
            WRITE(IOUT,23)
          else if (keyword.eq.'COMPLEX') then
            ifdparam = 3
            WRITE(IOUT,25)
          else
            write(errmsg,'(3a)')                                                 &
              'UNKNOWN IMS COMPLEXITY OPTION (', trim(keyword), ').'
            call store_error(errmsg)
          end if
        case ('CSV_OUTER_OUTPUT')
          call this%parser%GetStringCaps(keyword)
          if (keyword == 'FILEOUT') then
            call this%parser%GetString(fname)
            this%icsvouterout = getunit()
            call openfile(this%icsvouterout, iout, fname, 'CSV_OUTER_OUTPUT',    &
                          filstat_opt='REPLACE')
            write(iout,fmtcsvout) trim(fname), this%icsvouterout
          else
            write(errmsg,'(a)') 'OPTIONAL CSV_OUTER_OUTPUT ' //                  &
              'KEYWORD MUST BE FOLLOWED BY FILEOUT'
            call store_error(errmsg)
          end if
        case ('CSV_INNER_OUTPUT')
          call this%parser%GetStringCaps(keyword)
          if (keyword == 'FILEOUT') then
            call this%parser%GetString(fname)
            this%icsvinnerout = getunit()
            call openfile(this%icsvinnerout, iout, fname, 'CSV_INNER_OUTPUT',    &
                          filstat_opt='REPLACE')
            write(iout,fmtcsvout) trim(fname), this%icsvinnerout
          else
            write(errmsg,'(a)') 'OPTIONAL CSV_INNER_OUTPUT ' //                  &
              'KEYWORD MUST BE FOLLOWED BY FILEOUT'
            call store_error(errmsg)
          end if
        case ('NO_PTC')
          call this%parser%GetStringCaps(keyword)
          select case(keyword)
            case ('ALL')
              ival = 0
              msg = 'ALL'
            case ('FIRST')
              ival = -1
              msg = 'THE FIRST'
            case default
              ival = 0
              msg = 'ALL'
          end select
          this%iallowptc = ival
          write(IOUT,'(1x,A)') 'PSEUDO-TRANSIENT CONTINUATION DISABLED FOR' // &
            ' ' // trim(adjustl(msg)) // ' STRESS-PERIOD(S)'
        case('ATS_OUTER_MAXIMUM_FRACTION')
          rval = this%parser%GetDouble()
          if (rval < DZERO .or. rval > DHALF) then
            write(errmsg,'(a,G0)') 'VALUE FOR ATS_OUTER_MAXIMUM_FRAC MUST BE &
              &BETWEEN 0 AND 0.5.  FOUND ', rval
            call store_error(errmsg)
          end if
          this%atsfrac = rval
          write(IOUT,'(1x,A,G0)') 'ADAPTIVE TIME STEP SETTING FOUND.  FRACTION &
            &OF OUTER MAXIMUM USED TO INCREASE OR DECREASE TIME STEP SIZE IS ',&
            &this%atsfrac
        !
        ! -- DEPRECATED OPTIONS
        case ('CSV_OUTPUT')
          call this%parser%GetStringCaps(keyword)
          if (keyword == 'FILEOUT') then
            call this%parser%GetString(fname)
            this%icsvouterout = getunit()
            call openfile(this%icsvouterout, iout, fname, 'CSV_OUTPUT',          &
                          filstat_opt='REPLACE')
            write(iout,fmtcsvout) trim(fname), this%icsvouterout
            !
            ! -- create warning message
            write(warnmsg,'(a)')                                                 &
              'OUTER ITERATION INFORMATION WILL BE SAVED TO ' // trim(fname)
            !
            ! -- create deprecation warning
            call deprecation_warning('OPTIONS', 'CSV_OUTPUT', '6.1.1',            &
                                     warnmsg, this%parser%GetUnit())
          else
            write(errmsg,'(a)') 'OPTIONAL CSV_OUTPUT ' //                        &
              'KEYWORD MUST BE FOLLOWED BY FILEOUT'
            call store_error(errmsg)
          end if
        !
        ! -- right now these are options that are only available in the
        !    development version and are not included in the documentation.
        !    These options are only available when IDEVELOPMODE in
        !    constants module is set to 1
        case ('DEV_PTC')
          call this%parser%DevOpt()
          this%iallowptc = 1
          write(IOUT,'(1x,A)') 'PSEUDO-TRANSIENT CONTINUATION ENABLED'
        case('DEV_PTC_OUTPUT')
          call this%parser%DevOpt()
          this%iallowptc = 1
          call this%parser%GetStringCaps(keyword)
          if (keyword == 'FILEOUT') then
            call this%parser%GetString(fname)
            this%iptcout = getunit()
            call openfile(this%iptcout, iout, fname, 'PTC-OUT',                  &
                          filstat_opt='REPLACE')
            write(iout,fmtptcout) trim(fname), this%iptcout
          else
            write(errmsg,'(a)')                                                  &
              'OPTIONAL PTC_OUTPUT KEYWORD MUST BE FOLLOWED BY FILEOUT'
            call store_error(errmsg)
          end if
        case ('DEV_PTC_OPTION')
          call this%parser%DevOpt()
          this%iallowptc = 1
          this%iptcopt = 1
          write(IOUT,'(1x,A)')                                                   &
            'PSEUDO-TRANSIENT CONTINUATION USES BNORM AND L2NORM TO ' //         &
            'SET INITIAL VALUE'
        case ('DEV_PTC_EXPONENT')
          call this%parser%DevOpt()
          rval = this%parser%GetDouble()
          if (rval < DZERO) then
            write(errmsg,'(a)') 'PTC_EXPONENT MUST BE > 0.'
            call store_error(errmsg)
          else
            this%iallowptc = 1
            this%ptcexp = rval
            write(IOUT,'(1x,A,1x,g15.7)')                                        &
              'PSEUDO-TRANSIENT CONTINUATION EXPONENT', this%ptcexp
          end if
        case ('DEV_PTC_THRESHOLD')
          call this%parser%DevOpt()
          rval = this%parser%GetDouble()
          if (rval < DZERO) then
            write(errmsg,'(a)') 'PTC_THRESHOLD MUST BE > 0.'
            call store_error(errmsg)
          else
            this%iallowptc = 1
            this%ptcthresh = rval
            write(IOUT,'(1x,A,1x,g15.7)')                                        &
              'PSEUDO-TRANSIENT CONTINUATION THRESHOLD', this%ptcthresh
          end if
        case ('DEV_PTC_DEL0')
          call this%parser%DevOpt()
          rval = this%parser%GetDouble()
          if (rval < DZERO) then
            write(errmsg,'(a)')'IMS sln_ar: PTC_DEL0 MUST BE > 0.'
            call store_error(errmsg)
          else
            this%iallowptc = 1
            this%ptcdel0 = rval
            write(IOUT,'(1x,A,1x,g15.7)')                                        &
              'PSEUDO-TRANSIENT CONTINUATION INITIAL TIMESTEP', this%ptcdel0
          end if
        case default
          write(errmsg,'(a,2(1x,a))')                                            &
            'UNKNOWN IMS OPTION  (', trim(keyword), ').'
          call store_error(errmsg)
        end select
      end do
      write(iout,'(1x,a)')'END OF IMS OPTIONS'
    else
      write(iout,'(1x,a)')'NO IMS OPTION BLOCK DETECTED.'
    end if

00021 FORMAT(1X,'SIMPLE OPTION:',/,                                              &
    &       1X,'DEFAULT SOLVER INPUT VALUES FOR FAST SOLUTIONS')
00023 FORMAT(1X,'MODERATE OPTION:',/,1X,'DEFAULT SOLVER',                        &
    &          ' INPUT VALUES REFLECT MODERETELY NONLINEAR MODEL')
00025 FORMAT(1X,'COMPLEX OPTION:',/,1X,'DEFAULT SOLVER',                         &
    & ' INPUT VALUES REFLECT STRONGLY NONLINEAR MODEL')

    !-------READ NONLINEAR ITERATION PARAMETERS AND LINEAR SOLVER SELECTION INDEX
    ! -- set default nonlinear parameters
    call this%sln_setouter(ifdparam)
    !
    ! -- get NONLINEAR block
    call this%parser%GetBlock('NONLINEAR', isfound, ierr, &
      supportOpenClose=.true., blockRequired=.FALSE.)
    !
    ! -- parse NONLINEAR block if detected
    if (isfound) then
      write(iout,'(/1x,a)')'PROCESSING IMS NONLINEAR'
      do
        call this%parser%GetNextLine(endOfBlock)
        if (endOfBlock) exit
        call this%parser%GetStringCaps(keyword)
        ! -- parse keyword
        select case (keyword)
        case ('OUTER_DVCLOSE')
          this%dvclose  = this%parser%GetDouble()
        case ('OUTER_MAXIMUM')
          this%mxiter  = this%parser%GetInteger()
        case ('UNDER_RELAXATION')
          call this%parser%GetStringCaps(keyword)
          ival = 0
          if (keyword == 'NONE') then
            ival = 0
          else if (keyword == 'SIMPLE') then
            ival = 1
          else if (keyword == 'COOLEY') then
            ival = 2
          else if (keyword == 'DBD') then
            ival = 3
          else
            write(errmsg,'(3a)')                                                 &
              'UNKNOWN UNDER_RELAXATION SPECIFIED (', trim(keyword), ').'
            call store_error(errmsg)
          end if
          this%nonmeth = ival
        case ('LINEAR_SOLVER')
          call this%parser%GetStringCaps(keyword)
          ival = 1
          if (keyword.eq.'DEFAULT' .or.                                          &
              keyword.eq.'LINEAR') then
            ival = 1
          else
            write(errmsg,'(3a)')                                                 &
              'UNKNOWN LINEAR_SOLVER SPECIFIED (', trim(keyword), ').'
            call store_error(errmsg)
          end if
          this%linmeth = ival
        case ('UNDER_RELAXATION_THETA')
          this%theta = this%parser%GetDouble()
        case ('UNDER_RELAXATION_KAPPA')
          this%akappa = this%parser%GetDouble()
        case ('UNDER_RELAXATION_GAMMA')
          this%gamma = this%parser%GetDouble()
        case ('UNDER_RELAXATION_MOMENTUM')
          this%amomentum  = this%parser%GetDouble()
        case ('BACKTRACKING_NUMBER')
          this%numtrack = this%parser%GetInteger()
          IF (this%numtrack > 0) this%ibflag = 1
        case ('BACKTRACKING_TOLERANCE')
          this%btol = this%parser%GetDouble()
        case ('BACKTRACKING_REDUCTION_FACTOR')
          this%breduc = this%parser%GetDouble()
        case ('BACKTRACKING_RESIDUAL_LIMIT')
          this%res_lim = this%parser%GetDouble()
        !
        ! -- deprecated variables
        case ('OUTER_HCLOSE')
          this%dvclose  = this%parser%GetDouble()
          !
          ! -- create warning message
          write(warnmsg,'(a)')                                                   &
            'SETTING OUTER_DVCLOSE TO OUTER_HCLOSE VALUE'
          !
          ! -- create deprecation warning
          call deprecation_warning('NONLINEAR', 'OUTER_HCLOSE', '6.1.1',         &
                                   warnmsg, this%parser%GetUnit())
        case ('OUTER_RCLOSEBND')
          !
          ! -- create warning message
          write(warnmsg,'(a)')                                                   &
            'OUTER_DVCLOSE IS USED TO EVALUATE PACKAGE CONVERGENCE'
          !
          ! -- create deprecation warning
          call deprecation_warning('NONLINEAR', 'OUTER_RCLOSEBND', '6.1.1',      &
                                   warnmsg, this%parser%GetUnit())
        case default
          write(errmsg,'(3a)')                                                   &
            'UNKNOWN IMS NONLINEAR KEYWORD (', trim(keyword), ').'
          call store_error(errmsg)
        end select
      end do
      write(iout,'(1x,a)') 'END OF IMS NONLINEAR DATA'
    else
      if (IFDPARAM.EQ.0) then
        write(errmsg,'(a)') 'NO IMS NONLINEAR BLOCK DETECTED.'
        call store_error(errmsg)
      end if
    end if
    !
    if (THIS%theta < DEM3) then
      this%theta = DEM3
    end if
    !
    ! -- backtracking should only be used if this%nonmeth > 0
    if (this%nonmeth < 1) then
      this%ibflag = 0
    end if
    !
    ! -- check that MXITER is greater than zero
    if (this%mxiter <= 0) then
      write(errmsg,'(a)') 'OUTER ITERATION NUMBER MUST BE > 0.'
      call store_error(errmsg)
    END IF
    !
    !
    isymflg = 1
    if ( this%nonmeth > 0 )then
      WRITE(IOUT,*) '**UNDER-RELAXATION WILL BE USED***'
      WRITE(IOUT,*)
      isymflg = 0
    elseif ( this%nonmeth == 0 )then
      WRITE(IOUT,*) '***UNDER-RELAXATION WILL NOT BE USED***'
      WRITE(IOUT,*)
    ELSE
      WRITE(errmsg,'(a)')                                                      &
        'INCORRECT VALUE FOR VARIABLE NONMETH WAS SPECIFIED.'
      call store_error(errmsg)
    END IF
    !
    ! -- ensure gamma is > 0 for simple
    if (this%nonmeth == 1) then
      if (this%gamma == 0) then
        WRITE(errmsg, '(a)')                                                   &
          'GAMMA must be greater than zero if SIMPLE under-relaxation is used.'
        call store_error(errmsg)
      end if
    end if
    !
    ! -- call secondary subroutine to initialize and read linear 
    !    solver parameters IMSLINEAR solver
    if ( this%linmeth == 1 )then
      allocate(this%imslinear)
      WRITE(IOUT,*) '***IMS LINEAR SOLVER WILL BE USED***'
      call this%imslinear%imslinear_allocate(this%name, this%parser, IOUT,       &
                                             this%iprims, this%mxiter,           &
                                             ifdparam, imslinear,                &
                                             this%neq, this%nja, this%ia,        &
                                             this%ja, this%amat, this%rhs,       &
                                             this%x, this%nitermax)
      WRITE(IOUT,*)
      isymflg = 0
      if ( imslinear.eq.1 ) isymflg = 1
    !
    ! -- incorrect linear solver flag
    ELSE
      WRITE(errmsg, '(a)')                                                       &
        'INCORRECT VALUE FOR LINEAR SOLUTION METHOD SPECIFIED.'
      call store_error(errmsg)
    END IF
    !
    ! -- If CG, then go through each model and each exchange and check
    !    for asymmetry
    if (isymflg == 1) then
      !
      ! -- Models
      do i = 1, this%modellist%Count()
        mp => GetNumericalModelFromList(this%modellist, i)
        if (mp%get_iasym() /= 0) then
          write(errmsg, fmterrasym) 'MODEL', trim(adjustl(mp%name))
          call store_error(errmsg)
        endif
      enddo
      !
      ! -- Exchanges
      do i = 1, this%exchangelist%Count()
        cp => GetNumericalExchangeFromList(this%exchangelist, i)
        if (cp%get_iasym() /= 0) then
          write(errmsg, fmterrasym) 'EXCHANGE', trim(adjustl(cp%name))
          call store_error(errmsg)
        endif
      enddo
      !
    endif
    !
    ! -- write solver data to output file
    !
    ! -- non-linear solver data
    WRITE(IOUT,9002) this%dvclose, this%mxiter,                                &
                     this%iprims, this%nonmeth, this%linmeth
    !
    ! -- standard outer iteration formats
9002 FORMAT(1X,'OUTER ITERATION CONVERGENCE CRITERION    (DVCLOSE) = ', E15.6, &
    &      /1X,'MAXIMUM NUMBER OF OUTER ITERATIONS        (MXITER) = ', I0,    &
    &      /1X,'SOLVER PRINTOUT INDEX                     (IPRIMS) = ', I0,    &
    &      /1X,'NONLINEAR ITERATION METHOD            (NONLINMETH) = ', I0,    &
    &      /1X,'LINEAR SOLUTION METHOD                   (LINMETH) = ', I0)
    !
    if (this%nonmeth == 1) then ! simple
      write(iout, 9003) this%gamma
    else if (this%nonmeth == 2) then ! cooley
      write(iout, 9004) this%gamma
    else if (this%nonmeth == 3) then ! delta bar delta
      write(iout, 9005) this%theta, this%akappa, this%gamma, this%amomentum
    end if
    !
    ! -- write backtracking information
    if(this%numtrack /= 0) write(iout, 9006) this%numtrack, this%btol,       &
                                             this%breduc,this%res_lim
    !
    ! -- under-relaxation formats (simple, cooley, dbd)
9003 FORMAT(1X,'UNDER-RELAXATION FACTOR                    (GAMMA) = ', E15.6)
9004 FORMAT(1X,'UNDER-RELAXATION PREVIOUS HISTORY FACTOR   (GAMMA) = ', E15.6)
9005 FORMAT(1X,'UNDER-RELAXATION WEIGHT REDUCTION FACTOR   (THETA) = ', E15.6, &
    &      /1X,'UNDER-RELAXATION WEIGHT INCREASE INCREMENT (KAPPA) = ', E15.6, &
    &      /1X,'UNDER-RELAXATION PREVIOUS HISTORY FACTOR   (GAMMA) = ', E15.6, &
    &      /1X,'UNDER-RELAXATION MOMENTUM TERM         (AMOMENTUM) = ', E15.6)
    !
    ! -- backtracking formats
9006 FORMAT(1X,'MAXIMUM NUMBER OF BACKTRACKS            (NUMTRACK) = ', I0,    &
    &      /1X,'BACKTRACKING TOLERANCE FACTOR               (BTOL) = ', E15.6, &
    &      /1X,'BACKTRACKING REDUCTION FACTOR             (BREDUC) = ', E15.6, &
    &      /1X,'BACKTRACKING RESIDUAL LIMIT              (RES_LIM) = ', E15.6)
    !
    ! -- linear solver data
    call this%imslinear%imslinear_summary(this%mxiter)

    ! -- write summary of solver error messages
    ierr = count_errors()
    if (ierr>0) then
      call this%parser%StoreErrorUnit()
    end if
    !
    ! reallocate space for nonlinear arrays and initialize
    call mem_reallocate(this%hncg, this%mxiter, 'HNCG', this%name)
    call mem_reallocate(this%lrch, 3, this%mxiter, 'LRCH', this%name)

    ! delta-bar-delta under-relaxation
    if(this%nonmeth == 3)then
      call mem_reallocate(this%wsave, this%neq, 'WSAVE', this%name)
      call mem_reallocate(this%hchold, this%neq, 'HCHOLD', this%name)
      call mem_reallocate(this%deold, this%neq, 'DEOLD', this%name)
      do i = 1, this%neq
        this%wsave(i) = DZERO
        this%hchold(i) = DZERO
        this%deold(i) = DZERO
      end do
    endif
    this%hncg = DZERO
    this%lrch = 0

    ! allocate space for saving solver convergence history
    if (this%iprims == 2 .or. this%icsvinnerout > 0) then
      this%nitermax = this%nitermax * this%mxiter
    else
      this%nitermax = 1
    end if

    allocate(this%caccel(this%nitermax))

    im = this%convnmod
    call mem_reallocate(this%itinner, this%nitermax, 'ITINNER',                &
                        trim(this%name))
    call mem_reallocate(this%convlocdv, im, this%nitermax, 'CONVLOCDV',        &
                        trim(this%name))
    call mem_reallocate(this%convlocdr, im, this%nitermax, 'CONVLOCDR',        &
                        trim(this%name))
    call mem_reallocate(this%convdvmax, im, this%nitermax, 'CONVDVMAX',        &
                        trim(this%name))
    call mem_reallocate(this%convdrmax, im, this%nitermax, 'CONVDRMAX',        &
                        trim(this%name))
    do i = 1, this%nitermax
      this%itinner(i) = 0
      do im = 1, this%convnmod
        this%convlocdv(im, i) = 0
        this%convlocdr(im, i) = 0
        this%convdvmax(im, i) = DZERO
        this%convdrmax(im, i) = DZERO
      end do
    end do
    !
    ! -- check for numerical solution errors
    ierr = count_errors()
    if (ierr > 0) then
      call this%parser%StoreErrorUnit()
    end if
    !
    ! -- close ims input file
    call this%parser%Clear()
    !
    ! -- return
    return
  end subroutine sln_ar

  !> @ brief Calculate delt
  !!
  !!  Calculate time step length.
  !!
  !<
  subroutine sln_calculate_delt(this)
    ! -- modules
    use TdisModule, only: kstp, kper, delt
    use AdaptiveTimeStepModule, only: ats_submit_delt
    use ConstantsModule, only: DTWO, DTHREE
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    ! -- local variables
    integer(I4B) :: idir
    real(DP) :: delt_temp
    real(DP) :: fact_lower
    real(DP) :: fact_upper
    !
    ! -- increase or decrease delt based on kiter fraction.  atsfrac should be
    !    a value of about 1/3.  If the number of outer iterations is less than
    !    1/3 of mxiter, then increase step size.  If the number of outer
    !    iterations is greater than 2/3 of mxiter, then decrease step size.
    if (this%atsfrac > DZERO) then
      delt_temp = delt
      fact_lower = this%mxiter * this%atsfrac
      fact_upper = this%mxiter - fact_lower
      if (this%iouttot_timestep < int(fact_lower)) then
        ! -- increase delt according to tsfactats
        idir = 1 
      else if (this%iouttot_timestep > int(fact_upper)) then
        ! -- decrease delt according to tsfactats
        idir = -1 
      else
        ! -- do not change delt
        idir = 0  
      end if
      !
      ! -- submit stable dt for upcoming step
      call ats_submit_delt(kstp, kper, delt_temp, this%memoryPath, idir=idir)
    end if
    !
    return
  end subroutine sln_calculate_delt
  
  !> @ brief Advance solution
  !!
  !!  Advance solution.
  !!
  !<
  subroutine sln_ad(this)
    ! -- modules
    use TdisModule, only: kstp, kper
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    !
    ! -- write headers to CSV file
    if (kper == 1 .and. kstp == 1) then
      call this%writeCSVHeader()
    end if
      
    ! write PTC info on models to iout
    call this%writePTCInfoToFile(kper)
            
    ! reset convergence flag and inner solve counter
    this%icnvg = 0
    this%itertot_timestep = 0   
    this%iouttot_timestep = 0   
    
    return
  end subroutine sln_ad
  
  !> @ brief Output solution
  !!
  !!  Output solution data. Currently does nothing.
  !!
  !<
  subroutine sln_ot(this)
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    !
    ! -- Nothing to do here
    !
    ! -- return
    return
  end subroutine sln_ot

  !> @ brief Finalize solution
  !!
  !!  Finalize a solution.
  !!
  !<
  subroutine sln_fp(this)
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    !
    ! -- write timer output 
    if (IDEVELOPMODE == 1) then
      write(this%imslinear%iout, '(//1x,a,1x,a,1x,a)')                         &
        'Solution', trim(adjustl(this%name)), 'summary'
      write(this%imslinear%iout, "(1x,70('-'))")
      write(this%imslinear%iout, '(1x,a,1x,g0,1x,a)')                          &
        'Total formulate time: ', this%ttform, 'seconds'
      write(this%imslinear%iout, '(1x,a,1x,g0,1x,a,/)')                        &
        'Total solution time:  ', this%ttsoln, 'seconds'
    end if
    !
    ! -- return
    return
  end subroutine sln_fp

  !> @ brief Deallocate solution
  !!
  !!  Deallocate a solution.
  !!
  !<
  subroutine sln_da(this)
    ! -- modules
    use MemoryManagerModule, only: mem_deallocate
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    !
    ! -- IMSLinearModule
    call this%imslinear%imslinear_da()
    deallocate(this%imslinear)
    !
    ! -- lists
    call this%modellist%Clear()
    call this%exchangelist%Clear()
    deallocate(this%modellist)
    deallocate(this%exchangelist)
    !
    ! -- character arrays
    deallocate(this%caccel)
    !
    ! -- inner iteration table object
    if (associated(this%innertab)) then
      call this%innertab%table_da()
      deallocate(this%innertab)
      nullify(this%innertab)
    end if
    !
    ! -- outer iteration table object
    if (associated(this%outertab)) then
      call this%outertab%table_da()
      deallocate(this%outertab)
      nullify(this%outertab)
    end if
    !
    ! -- arrays
    call mem_deallocate(this%ja)
    call mem_deallocate(this%amat)
    call mem_deallocate(this%ia)
    call mem_deallocate(this%x)
    call mem_deallocate(this%rhs)
    call mem_deallocate(this%active)
    call mem_deallocate(this%xtemp)
    call mem_deallocate(this%dxold)
    call mem_deallocate(this%hncg)
    call mem_deallocate(this%lrch)
    call mem_deallocate(this%wsave)
    call mem_deallocate(this%hchold)
    call mem_deallocate(this%deold)
    call mem_deallocate(this%convmodstart)
    call mem_deallocate(this%locdv)
    call mem_deallocate(this%locdr)
    call mem_deallocate(this%itinner)
    call mem_deallocate(this%convlocdv)
    call mem_deallocate(this%convlocdr)
    call mem_deallocate(this%dvmax)
    call mem_deallocate(this%drmax)
    call mem_deallocate(this%convdvmax)
    call mem_deallocate(this%convdrmax)
    !
    ! -- Scalars
    call mem_deallocate(this%id)
    call mem_deallocate(this%iu)
    call mem_deallocate(this%ttform)
    call mem_deallocate(this%ttsoln)
    call mem_deallocate(this%neq)
    call mem_deallocate(this%nja)
    call mem_deallocate(this%dvclose)
    call mem_deallocate(this%bigchold)
    call mem_deallocate(this%bigch)
    call mem_deallocate(this%relaxold)
    call mem_deallocate(this%res_prev)
    call mem_deallocate(this%res_new)
    call mem_deallocate(this%icnvg)
    call mem_deallocate(this%itertot_timestep)
    call mem_deallocate(this%iouttot_timestep)
    call mem_deallocate(this%itertot_sim)
    call mem_deallocate(this%mxiter)
    call mem_deallocate(this%linmeth)
    call mem_deallocate(this%nonmeth)
    call mem_deallocate(this%iprims)
    call mem_deallocate(this%theta)
    call mem_deallocate(this%akappa)
    call mem_deallocate(this%gamma)
    call mem_deallocate(this%amomentum)
    call mem_deallocate(this%breduc)
    call mem_deallocate(this%btol)
    call mem_deallocate(this%res_lim)
    call mem_deallocate(this%numtrack)
    call mem_deallocate(this%ibflag)
    call mem_deallocate(this%icsvouterout)
    call mem_deallocate(this%icsvinnerout)
    call mem_deallocate(this%nitermax)
    call mem_deallocate(this%convnmod)
    call mem_deallocate(this%iallowptc)
    call mem_deallocate(this%iptcopt)
    call mem_deallocate(this%iptcout)
    call mem_deallocate(this%l2norm0)
    call mem_deallocate(this%ptcdel)
    call mem_deallocate(this%ptcdel0)
    call mem_deallocate(this%ptcexp)
    call mem_deallocate(this%ptcthresh)
    call mem_deallocate(this%ptcrat)
    call mem_deallocate(this%atsfrac)
    !
    ! -- return
    return
  end subroutine sln_da

  !> @ brief Solve solution
  !!
  !!  Solve the models in this solution for kper and kstp.
  !!
  !<
  subroutine sln_ca(this, isgcnvg, isuppress_output)
    ! -- dummy variables
    class(NumericalSolutionType) :: this            !< NumericalSolutionType instance
    integer(I4B), intent(inout) :: isgcnvg          !< solution group convergence flag
    integer(I4B), intent(in) :: isuppress_output    !< flag for suppressing output
    ! -- local variables
    class(NumericalModelType), pointer :: mp => null()
    character(len=LINELENGTH) :: line
    character(len=LINELENGTH) :: fmt
    integer(I4B) :: im
    integer(I4B) :: kiter   ! non-linear iteration counter
! ------------------------------------------------------------------------------
    
    ! advance the models, exchanges, and solution
    call this%prepareSolve()
    
    select case (isim_mode)
      case (MVALIDATE)
        line = 'mode="validation" -- Skipping matrix assembly and solution.'
        fmt = "(/,1x,a,/)"
        do im = 1, this%modellist%Count()
          mp => GetNumericalModelFromList(this%modellist, im)
          call mp%model_message(line, fmt=fmt)
        end do
      case(MNORMAL)
        ! nonlinear iteration loop for this solution
        outerloop: do kiter = 1, this%mxiter
           
          ! perform a single iteration
          call this%solve(kiter)     
        
          ! exit if converged
          if (this%icnvg == 1) then
            exit outerloop
          end if
        
        end do outerloop
      
        ! finish up, write convergence info, CSV file, budgets and flows, ...
        call this%finalizeSolve(kiter, isgcnvg, isuppress_output)   
    end select
    !
    ! -- return
    return
    
  end subroutine sln_ca
       
  !> @ brief CSV header
  !!
  !!  Write header for solver output to comma-separated value files.
  !!
  !<
  subroutine writeCSVHeader(this)  
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    ! local variables
    integer(I4B) :: im
    class(NumericalModelType), pointer :: mp => null()
    !
    ! -- outer iteration csv header
    if (this%icsvouterout > 0) then
      write(this%icsvouterout, '(*(G0,:,","))')                              &
        'total_inner_iterations', 'totim', 'kper', 'kstp', 'nouter',         &
        'inner_iterations', 'solution_outer_dvmax',                          &
        'solution_outer_dvmax_model', 'solution_outer_dvmax_package',        &
        'solution_outer_dvmax_node'
    end if
    !
    ! -- inner iteration csv header
    if (this%icsvinnerout > 0) then
      write(this%icsvinnerout, '(*(G0,:,","))', advance='NO')                &
        'total_inner_iterations', 'totim', 'kper', 'kstp', 'nouter',         &
        'ninner', 'solution_inner_dvmax', 'solution_inner_dvmax_model',      &
        'solution_inner_dvmax_node'
      write(this%icsvinnerout, '(*(G0,:,","))', advance='NO')              &
        '', 'solution_inner_drmax', 'solution_inner_drmax_model',          &
        'solution_inner_drmax_node', 'solution_inner_alpha'
      if (this%imslinear%ilinmeth == 2) then
        write(this%icsvinnerout, '(*(G0,:,","))', advance='NO')            &
          '', 'solution_inner_omega'
      end if
      ! -- check for more than one model
      if (this%convnmod > 1) then
        do im=1,this%modellist%Count()
          mp => GetNumericalModelFromList(this%modellist, im)
          write(this%icsvinnerout, '(*(G0,:,","))', advance='NO')          &
            '', trim(adjustl(mp%name)) // '_inner_dvmax',                  &
            trim(adjustl(mp%name)) // '_inner_dvmax_node',                 &
            trim(adjustl(mp%name)) // '_inner_drmax',                      &
            trim(adjustl(mp%name)) // '_inner_drmax_node'
        end do
      end if
      write(this%icsvinnerout,'(a)') ''
    end if
    !
    ! -- return
    return
  end subroutine writeCSVHeader
  
  !> @ brief PTC header
  !!
  !!  Write header for pseudo-transient continuation information to a file.
  !!
  !<
  subroutine writePTCInfoToFile(this, kper)
    ! -- dummy variables
    class(NumericalSolutionType) :: this !< NumericalSolutionType instance
    integer(I4B), intent(in) :: kper     !< current stress period number
    ! -- local variable
    integer(I4B) :: n, im, iallowptc, iptc
    class(NumericalModelType), pointer :: mp => null()
    
    ! -- determine if PTC will be used in any model
    n = 1
    do im = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_ptcchk(iptc)
      !
      ! -- set iallowptc
      ! -- no_ptc_option is FIRST
      if (this%iallowptc < 0) then
        if (kper > 1) then
          iallowptc = 1
        else
          iallowptc = 0
        end if
      ! -- no_ptc_option is ALL (0) or using PTC (1)
      else
        iallowptc = this%iallowptc
      end if
      iptc = iptc * iallowptc
      if (iptc /= 0) then
        if (n == 1) then
          write(iout, '(//)')
          n = 0
        end if
        write(iout, '(1x,a,1x,i0,1x,3a)')                                           &
          'PSEUDO-TRANSIENT CONTINUATION WILL BE APPLIED TO MODEL', im, '("',        &
          trim(adjustl(mp%name)), '") DURING THIS TIME STEP'
      end if
    enddo
    
  end subroutine writePTCInfoToFile
  
  !> @ brief prepare to solve
  !!
  !!  Prepare for the system solve by advancing the simulation.
  !!
  !<
  subroutine prepareSolve(this)
    ! -- dummy variables
    class(NumericalSolutionType) :: this !< NumericalSolutionType instance
    ! -- local variables
    integer(I4B) :: ic
    integer(I4B) :: im
    class(NumericalExchangeType), pointer :: cp => null()
    class(NumericalModelType), pointer :: mp => null()
    
     ! -- Exchange advance
    do ic=1,this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_ad()
    enddo
    
    ! -- Model advance
    do im = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_ad()
    enddo
    
    ! advance solution
    call this%sln_ad()
    
  end subroutine prepareSolve
  
  !> @ brief Build and solve the simulation
  !!
  !! Builds and solve the system for this numerical solution. 
  !! It roughly consists of the following steps
  !! (1) backtracking, (2) reset amat and rhs (3) calculate matrix 
  !! terms (*_cf), (4) add coefficients to matrix (*_fc), (6) newton-raphson,
  !! (6) PTC, (7) linear solve, (8) convergence checks, (9) write output,
  !! and (10) underrelaxation
  !!
  !<
  subroutine solve(this, kiter)
    ! -- modules
    use TdisModule, only: kstp, kper, totim
    ! -- dummy variables
    class(NumericalSolutionType) :: this    !< NumericalSolutionType instance
    integer(I4B), intent(in) :: kiter       !< Picard iteration number
    ! -- local variables
    class(NumericalModelType), pointer :: mp => null()
    class(NumericalExchangeType), pointer :: cp => null()    
    character(len=LINELENGTH) :: title
    character(len=LINELENGTH) :: tag
    character(len=LINELENGTH) :: line
    character(len=LENPAKLOC) :: cmod
    character(len=LENPAKLOC) :: cpak
    character(len=LENPAKLOC) :: cpakout
    character(len=LENPAKLOC) :: strh
    character(len=25) :: cval
    character(len=7) :: cmsg
    integer(I4B) :: ic
    integer(I4B) :: im    
    integer(I4B) :: icsv0
    integer(I4B) :: kcsv0
    integer(I4B) :: ntabrows
    integer(I4B) :: ntabcols
    integer(I4B) :: i0, i1    
    integer(I4B) :: itestmat, n
    integer(I4B) :: iter    
    integer(I4B) :: inewtonur    
    integer(I4B) :: locmax_nur    
    integer(I4B) :: iend
    integer(I4B) :: icnvgmod
    integer(I4B) :: iptc
    integer(I4B) :: nodeu
    integer(I4B) :: ipak
    integer(I4B) :: ipos0
    integer(I4B) :: ipos1
    real(DP) :: dxmax_nur
    real(DP) :: dxmax
    real(DP) :: ptcf
    real(DP) :: ttform
    real(DP) :: ttsoln
    real(DP) :: dpak
    real(DP) :: outer_hncg
    !
    ! -- initialize local variables
    icsv0 = max(1, this%itertot_sim + 1)
    kcsv0 = max(1, this%itertot_timestep + 1)
    !
    ! -- create header for outer iteration table
    if (this%iprims > 0) then
      if (.not. associated(this%outertab)) then
        !
        ! -- create outer iteration table
        ! -- table dimensions
        ntabrows = 1
        ntabcols = 6
        if (this%numtrack > 0) then
          ntabcols = ntabcols + 4
        end if
        !
        ! -- initialize table and define columns
        title = trim(this%memoryPath) // ' OUTER ITERATION SUMMARY'
        call table_cr(this%outertab, this%name, title)
        call this%outertab%table_df(ntabrows, ntabcols, iout,        &
                                    finalize=.FALSE.)
        tag = 'OUTER ITERATION STEP'
        call this%outertab%initialize_column(tag, 25, alignment=TABLEFT)
        tag = 'OUTER ITERATION'
        call this%outertab%initialize_column(tag, 10, alignment=TABRIGHT)
        tag = 'INNER ITERATION'
        call this%outertab%initialize_column(tag, 10, alignment=TABRIGHT)
        if (this%numtrack > 0) then
          tag = 'BACKTRACK FLAG'
          call this%outertab%initialize_column(tag, 10, alignment=TABRIGHT)
          tag = 'BACKTRACK ITERATIONS'
          call this%outertab%initialize_column(tag, 10, alignment=TABRIGHT)
          tag = 'INCOMING RESIDUAL'
          call this%outertab%initialize_column(tag, 15, alignment=TABRIGHT)
          tag = 'OUTGOING RESIDUAL'
          call this%outertab%initialize_column(tag, 15, alignment=TABRIGHT)
        end if
        tag = 'MAXIMUM CHANGE'
        call this%outertab%initialize_column(tag, 15, alignment=TABRIGHT)
        tag = 'STEP SUCCESS'
        call this%outertab%initialize_column(tag, 7, alignment=TABRIGHT)
        tag = 'MAXIMUM CHANGE MODEL-(CELLID) OR MODEL-PACKAGE-(NUMBER)'
        call this%outertab%initialize_column(tag, 34, alignment=TABRIGHT)
      end if
    end if
    !
    ! -- backtracking
    if (this%numtrack > 0) then
      call this%sln_backtracking(mp, cp, kiter)
    end if
    
    call code_timer(0, ttform, this%ttform)
        
    ! (re)build the solution matrix
    call this%sln_buildsystem(kiter, inewton=1)
    
    !
    ! -- Add exchange Newton-Raphson terms to solution
    do ic=1,this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_nr(kiter, this%ia, this%amat)
    enddo
    !
    ! -- Calculate pseudo-transient continuation factor for each model
    iptc = 0
    ptcf = DZERO
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_ptc(kiter, this%neq, this%nja,                         &
                        this%ia, this%ja, this%x,                          &
                        this%rhs, this%amat,                               &
                        iptc, ptcf)
    end do
    !
    ! -- Add model Newton-Raphson terms to solution
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_nr(kiter, this%amat, this%nja, 1)
    enddo
    call code_timer(1, ttform, this%ttform)
    !
    ! -- linear solve
    call code_timer(0, ttsoln, this%ttsoln)
    CALL this%sln_ls(kiter, kstp, kper, iter, iptc, ptcf)
    call code_timer(1, ttsoln, this%ttsoln)
    !
    ! -- increment counters storing the total number of linear and 
    !    non-linear iterations for this timestep and the total 
    !    number of linear iterations for all timesteps
    this%itertot_timestep = this%itertot_timestep + iter
    this%iouttot_timestep = this%iouttot_timestep + 1
    this%itertot_sim = this%itertot_sim + iter
    !
    ! -- save matrix to a file
    !    to enable set itestmat to 1 and recompile
    !-------------------------------------------------------
    itestmat = 0
    if (itestmat /= 0) then
      open(99,file='sol_MF6.TXT')
      WRITE(99,*) 'MATRIX SOLUTION FOLLOWS'
      WRITE(99,'(10(I8,G15.4))')  (n, this%x(N), N = 1, this%NEQ)
      close(99)
      call stop_with_error()
    end if
    !-------------------------------------------------------
    !    
    ! -- check convergence of solution
    call this%sln_outer_check(this%hncg(kiter), this%lrch(1,kiter))
    if (this%icnvg /= 0) then
      this%icnvg = 0
      if (abs(this%hncg(kiter)) <= this%dvclose) then
        this%icnvg = 1
      end if
    end if
    !
    ! -- set failure flag
    if (this%icnvg == 0) then
      cmsg = ' '
    else
      cmsg = '*'
    end if
    !
    ! -- set flag if this is the last outer iteration
    iend = 0
    if (kiter == this%mxiter) then
      iend = 1
    end if
    !
    ! -- Additional convergence check for pseudo-transient continuation
    !    term. Evaluate if the ptc value added to the diagonal has
    !    decayed sufficiently.
    if (iptc > 0) then
      if (this%icnvg /= 0) then
        if (this%ptcrat > this%ptcthresh) then
          this%icnvg = 0
          cmsg = trim(cmsg) // 'PTC'
          if (iend /= 0) then
            write(line, '(a)')                                                   &
              'PSEUDO-TRANSIENT CONTINUATION CAUSED CONVERGENCE FAILURE'
            call sim_message(line)
          end if
        end if
      end if
    end if
    !
    ! -- write maximum dependent-variable change from linear solver to list file
    if (this%iprims > 0) then
      cval = 'Model'
      call this%sln_get_loc(this%lrch(1,kiter), strh)
      !
      ! -- add data to outertab
      call this%outertab%add_term(cval)
      call this%outertab%add_term(kiter)
      call this%outertab%add_term(iter)
      if (this%numtrack > 0) then
        call this%outertab%add_term(' ')
        call this%outertab%add_term(' ')
        call this%outertab%add_term(' ')
        call this%outertab%add_term(' ')
      end if
      call this%outertab%add_term(this%hncg(kiter))
      call this%outertab%add_term(cmsg)
      call this%outertab%add_term(trim(strh))
    end if
    !
    ! -- Additional convergence check for exchanges
    do ic=1,this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_cc(this%icnvg)
    end do
    !
    ! -- additional convergence check for model packages
    icnvgmod = this%icnvg
    cpak = ' '
    ipak = 0
    dpak = DZERO
    do im = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%get_mcellid(0, cmod)
      call mp%model_cc(this%itertot_sim, kiter, iend, icnvgmod,                  &
                       cpak, ipak, dpak)
      if (ipak /= 0) then
        ipos0 = index(cpak, '-', back=.true.)
        ipos1 = len_trim(cpak)
        write(cpakout, '(a,a,"-(",i0,")",a)')                                    &
          trim(cmod), cpak(1:ipos0-1), ipak, cpak(ipos0:ipos1) 
      else
        cpakout = ' '
      end if
    end do
    !
    ! -- evaluate package convergence
    if (abs(dpak) > this%dvclose) then
      this%icnvg = 0
      ! -- write message to stdout
      if (iend /= 0) then
        write(line, '(3a)')                                                       &
          'PACKAGE (', trim(cpakout), ') CAUSED CONVERGENCE FAILURE'
        call sim_message(line)
      end if
    end if
    !
    ! -- write maximum change in package convergence check
    if (this%iprims > 0) then
      cval = 'Package'
      if (this%icnvg /= 1) then
        cmsg = ' '
      else
        cmsg = '*'
      end if
      if (len_trim(cpakout) > 0) then
        !
        ! -- add data to outertab
        call this%outertab%add_term(cval)
        call this%outertab%add_term(kiter)
        call this%outertab%add_term(' ')
        if (this%numtrack > 0) then
          call this%outertab%add_term(' ')
          call this%outertab%add_term(' ')
          call this%outertab%add_term(' ')
          call this%outertab%add_term(' ')
        end if
        call this%outertab%add_term(dpak)
        call this%outertab%add_term(cmsg)
        call this%outertab%add_term(cpakout)
      end if
    end if
    !
    ! -- under-relaxation - only done if convergence not achieved
    if (this%icnvg /= 1) then
      if (this%nonmeth > 0) then
        call this%sln_underrelax(kiter, this%hncg(kiter), this%neq,              &
                                 this%active, this%x, this%xtemp)
      else
        call this%sln_calcdx(this%neq, this%active,                              &
                              this%x, this%xtemp, this%dxold)
      endif
      !
      ! -- adjust heads by newton under-relaxation, if necessary
      inewtonur = 0
      dxmax_nur = DZERO
      locmax_nur = 0
      do im=1,this%modellist%Count()
        mp => GetNumericalModelFromList(this%modellist, im)
        i0 = mp%moffset + 1
        i1 = i0 + mp%neq - 1
        call mp%model_nur(mp%neq, this%x(i0:i1), this%xtemp(i0:i1),              &
                          this%dxold(i0:i1), inewtonur, dxmax_nur, locmax_nur)
      end do
      !
      ! -- check for convergence if newton under-relaxation applied
      if (inewtonur /= 0) then
        !
        ! -- calculate maximum change in heads in cells that have
        !    not been adjusted by newton under-relxation
        call this%sln_maxval(this%neq, this%dxold, dxmax)
        !
        ! -- evaluate convergence
        if (abs(dxmax) <= this%dvclose .and.                                     &
            abs(this%hncg(kiter)) <= this%dvclose .and.                          &
            abs(dpak) <= this%dvclose) then
          this%icnvg = 1
          !
          ! -- reset outer dependent-variable change and location for output
          call this%sln_outer_check(this%hncg(kiter), this%lrch(1,kiter))
          !
          ! -- write revised dependent-variable change data after 
          !    newton under-relaxation
          if (this%iprims > 0) then
            cval = 'Newton under-relaxation'
            cmsg = '*'
            call this%sln_get_loc(this%lrch(1,kiter), strh)
            !
            ! -- add data to outertab
            call this%outertab%add_term(cval)
            call this%outertab%add_term(kiter)
            call this%outertab%add_term(iter)
            if (this%numtrack > 0) then
              call this%outertab%add_term(' ')
              call this%outertab%add_term(' ')
              call this%outertab%add_term(' ')
              call this%outertab%add_term(' ')
            end if
            call this%outertab%add_term(this%hncg(kiter))
            call this%outertab%add_term(cmsg)
            call this%outertab%add_term(trim(strh))
          end if
        end if
      end if
    end if
    !
    ! -- write to outer iteration csv file
    if (this%icsvouterout > 0) then
      !
      ! -- set outer dependent-variable change variable
      outer_hncg = this%hncg(kiter)
      !
      ! -- model convergence error 
      if (abs(outer_hncg) > abs(dpak)) then
        !
        ! -- get model number and user node number
        call this%sln_get_nodeu(this%lrch(1,kiter), im, nodeu)
        cpakout = ''
      !
      ! -- package convergence error
      else
        !
        ! -- set convergence error, model number, user node number,
        !    and package name
        outer_hncg = dpak
        ipos0 = index(cmod, '_')
        read(cmod(1:ipos0-1), *) im
        nodeu = ipak
        ipos0 = index(cpak, '-', back=.true.)
        cpakout = cpak(1:ipos0-1)
      end if
      !
      ! -- write line to outer iteration csv file
      write(this%icsvouterout, '(*(G0,:,","))')                                  &
          this%itertot_sim, totim, kper, kstp, kiter, iter,                      &
          outer_hncg, im, trim(cpakout), nodeu
    end if
    !
    ! -- write to inner iteration csv file
    if (this%icsvinnerout > 0) then
      call this%csv_convergence_summary(this%icsvinnerout, totim, kper, kstp,    &
                                        kiter, iter, icsv0, kcsv0)
    end if
    
  end subroutine solve
  
  !> @ brief finalize a solution
  !!
  !!  Finalize the solution. Called after the outer iteration loop.
  !!
  !<
  subroutine finalizeSolve(this, kiter, isgcnvg, isuppress_output)
    ! -- modules
    use TdisModule, only: kper, kstp
    ! -- dummy variables
    class(NumericalSolutionType) :: this         !< NumericalSolutionType instance
    integer(I4B), intent(in) :: kiter            !< Picard iteration number after convergence or failure
    integer(I4B), intent(inout) :: isgcnvg       !< solution group convergence flag
    integer(I4B), intent(in) :: isuppress_output !< flag for suppressing output
    ! -- local variables
    integer(I4B) :: ic, im
    class(NumericalModelType), pointer :: mp => null()
    class(NumericalExchangeType), pointer :: cp => null()
    ! -- formats for convergence info 
    character(len=*), parameter :: fmtnocnvg =                                 &
      &"(1X,'Solution ', i0, ' did not converge for stress period ', i0,       &
      &' and time step ', i0)"
    character(len=*), parameter :: fmtcnvg =                                   &
      &"(1X, I0, ' CALLS TO NUMERICAL SOLUTION ', 'IN TIME STEP ', I0,         &
      &' STRESS PERIOD ',I0,/1X,I0,' TOTAL ITERATIONS')" 
    !
    ! -- finalize the outer iteration table
    if (this%iprims > 0) then
      call this%outertab%finalize_table()
    end if
    !
    ! -- write convergence info
    !
    ! -- convergence was achieved
    if (this%icnvg /= 0) then
      if (this%iprims > 0) then
        write(iout, fmtcnvg) kiter, kstp, kper, this%itertot_timestep
      end if
    !
    ! -- convergence was not achieved
    else
      write(iout, fmtnocnvg) this%id, kper, kstp
    end if
    !
    ! -- write inner iteration convergence summary
    if (this%iprims == 2) then
      !
      ! -- write summary for each model
      do im=1,this%modellist%Count()
        mp => GetNumericalModelFromList(this%modellist, im)
        call this%convergence_summary(mp%iout, im, this%itertot_timestep)
      end do
      !
      ! -- write summary for entire solution
      call this%convergence_summary(iout, this%convnmod+1, this%itertot_timestep)
    end if
    !
    ! -- set solution goup convergence flag
    if (this%icnvg == 0) isgcnvg = 0
    !
    ! -- Calculate flow for each model
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_cq(this%icnvg, isuppress_output)
    enddo
    !
    ! -- Calculate flow for each exchange
    do ic = 1, this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_cq(isgcnvg, isuppress_output, this%id)
    enddo
    !
    ! -- Budget terms for each model
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_bd(this%icnvg, isuppress_output)
    enddo
    !
    ! -- Budget terms for each exchange
    do ic = 1, this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_bd(isgcnvg, isuppress_output, this%id)
    enddo
    
  end subroutine finalizeSolve
  
  ! helper routine to calculate coefficients and setup the solution matrix
  subroutine sln_buildsystem(this, kiter, inewton)
    class(NumericalSolutionType) :: this
    integer(I4B), intent(in) :: kiter
    integer(I4B), intent(in) :: inewton
    
    ! local
    integer(I4B) :: im, ic
    class(NumericalModelType), pointer :: mp
    class(NumericalExchangeType), pointer :: cp
    !
    ! -- Set amat and rhs to zero
    call this%sln_reset()
    
    !
    ! -- Calculate the matrix terms for each exchange
    do ic=1,this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_cf(kiter)
    enddo
    !
    ! -- Calculate the matrix terms for each model
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_cf(kiter)
    enddo
    !
    ! -- Add exchange coefficients to the solution
    do ic=1,this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_fc(kiter, this%ia, this%amat, this%rhs, inewton)
    enddo
    !
    ! -- Add model coefficients to the solution
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_fc(kiter, this%amat, this%nja, inewton)
    enddo
    
  end subroutine sln_buildsystem
  
  !> @ brief Solution convergence summary
  !!
  !!  Save convergence summary to a File.
  !!
  !<
  subroutine convergence_summary(this, iu, im, itertot_timestep)
    ! -- modules
    use InputOutputModule, only:getunit
    ! -- dummy variables
    class(NumericalSolutionType) :: this          !< NumericalSolutionType instance
    integer(I4B), intent(in) :: iu                !< file unit number for summary file
    integer(I4B), intent(in) :: im                !< model number
    integer(I4B), intent(in) :: itertot_timestep  !< total iteration for the time step
    ! -- local variables
    character(len=LINELENGTH) :: title
    character(len=LINELENGTH) :: tag
    character(len=LENPAKLOC) :: strh
    character(len=LENPAKLOC) :: strr
    integer(I4B) :: ntabrows
    integer(I4B) :: ntabcols
    integer(I4B) :: i
    integer(I4B) :: i0
    integer(I4B) :: iouter
    integer(I4B) :: j
    integer(I4B) :: k
    integer(I4B) :: locdv
    integer(I4B) :: locdr
    real(DP) :: dv
    real(DP) :: dr
    !
    ! -- initialize local variables
    strh = ''
    strr = ''
    iouter = 1
    locdv = 0
    locdr = 0
    !
    ! -- initialize inner iteration summary table
    if (.not. associated(this%innertab)) then
      !
      ! -- create outer iteration table
      ! -- table dimensions
      ntabrows = itertot_timestep
      ntabcols = 7
      !
      ! -- initialize table and define columns
      title = trim(this%memoryPath) // ' INNER ITERATION SUMMARY'
      call table_cr(this%innertab, this%name, title)
      call this%innertab%table_df(ntabrows, ntabcols, iu)
      tag = 'TOTAL ITERATION'
      call this%innertab%initialize_column(tag, 10, alignment=TABRIGHT)
      tag = 'OUTER ITERATION'
      call this%innertab%initialize_column(tag, 10, alignment=TABRIGHT)
      tag = 'INNER ITERATION'
      call this%innertab%initialize_column(tag, 10, alignment=TABRIGHT)
      tag = 'MAXIMUM CHANGE'
      call this%innertab%initialize_column(tag, 15, alignment=TABRIGHT)
      tag = 'MAXIMUM CHANGE MODEL-(CELLID)'
      call this%innertab%initialize_column(tag, LENPAKLOC, alignment=TABRIGHT)
      tag = 'MAXIMUM RESIDUAL'
      call this%innertab%initialize_column(tag, 15, alignment=TABRIGHT)
      tag = 'MAXIMUM RESIDUAL MODEL-(CELLID)'
      call this%innertab%initialize_column(tag, LENPAKLOC, alignment=TABRIGHT)
    !
    ! -- reset the output unit and the number of rows (maxbound)
    else
      call this%innertab%set_maxbound(itertot_timestep)
      call this%innertab%set_iout(iu)
    end if
    !
    ! -- write the inner iteration summary to unit iu
    i0 = 0
    do k = 1, itertot_timestep
      i = this%itinner(k)
      if (i <= i0) then
        iouter = iouter + 1
      end if
      if (im > this%convnmod) then
        dv = DZERO
        dr = DZERO
        do j = 1, this%convnmod
          if (ABS(this%convdvmax(j, k)) > ABS(dv)) then
            locdv = this%convlocdv(j, k)
            dv = this%convdvmax(j, k)
          end if
          if (ABS(this%convdrmax(j, k)) > ABS(dr)) then
            locdr = this%convlocdr(j, k)
            dr = this%convdrmax(j, k)
          end if
        end do
      else
        locdv = this%convlocdv(im, k)
        locdr = this%convlocdr(im, k)
        dv = this%convdvmax(im, k)
        dr = this%convdrmax(im, k)
      end if
      call this%sln_get_loc(locdv, strh)
      call this%sln_get_loc(locdr, strr)
      !
      ! -- add data to innertab
      call this%innertab%add_term(k)
      call this%innertab%add_term(iouter)
      call this%innertab%add_term(i)
      call this%innertab%add_term(dv)
      call this%innertab%add_term(adjustr(trim(strh)))
      call this%innertab%add_term(dr)
      call this%innertab%add_term(adjustr(trim(strr)))
      !
      ! -- update i0
      i0 = i
    end do
    !
    ! -- return
    return
  end subroutine convergence_summary


  !> @ brief Solution convergence CSV summary
  !!
  !!  Save convergence summary to a comma-separated value file.
  !!
  !<
  subroutine csv_convergence_summary(this, iu, totim, kper, kstp, kouter,        &
                                     niter, istart, kstart)
    ! -- modules
    use InputOutputModule, only:getunit
    ! -- dummy variables
    class(NumericalSolutionType) :: this   !< NumericalSolutionType instance
    integer(I4B), intent(in) :: iu         !< file unit number
    real(DP), intent(in) :: totim          !< total simulation time
    integer(I4B), intent(in) :: kper       !< stress period number
    integer(I4B), intent(in) :: kstp       !< time step number
    integer(I4B), intent(in) :: kouter     !< number of outer (Picard) iterations
    integer(I4B), intent(in) :: niter      !< number of inner iteration in this time step
    integer(I4B), intent(in) :: istart     !< starting iteration number for this time step
    integer(I4B), intent(in) :: kstart     !< starting position in the conv* arrays
    ! -- local
    integer(I4B) :: itot
    integer(I4B) :: im
    integer(I4B) :: j
    integer(I4B) :: k
    integer(I4B) :: kpos
    integer(I4B) :: locdv
    integer(I4B) :: locdr
    integer(I4B) :: nodeu
    real(DP) :: dv
    real(DP) :: dr
! ------------------------------------------------------------------------------
    !
    ! -- initialize local variables
    itot = istart
    !
    ! -- write inner iteration results to the inner csv output file
    do k = 1, niter
      kpos = kstart + k - 1
      write(iu, '(*(G0,:,","))', advance='NO')                                 &
        itot, totim, kper, kstp, kouter, k
      !
      ! -- solution summary
      dv = DZERO
      dr = DZERO
      do j = 1, this%convnmod
        if (ABS(this%convdvmax(j, kpos)) > ABS(dv)) then
          locdv = this%convlocdv(j, kpos)
          dv = this%convdvmax(j, kpos)
        end if
        if (ABS(this%convdrmax(j, kpos)) > ABS(dr)) then
          locdr = this%convlocdr(j, kpos)
          dr = this%convdrmax(j, kpos)
        end if
      end do
      !
      ! -- get model number and user node number for dv
      call this%sln_get_nodeu(locdv, im, nodeu)
      write(iu, '(*(G0,:,","))', advance='NO') '', dv, im, nodeu
      !
      ! -- get model number and user node number for dr
      call this%sln_get_nodeu(locdr, im, nodeu)
      write(iu, '(*(G0,:,","))', advance='NO') '', dr, im, nodeu
      !
      ! -- write acceleration parameters
      write(iu, '(*(G0,:,","))', advance='NO')                                   &
        '', trim(adjustl(this%caccel(kpos)))
      !
      ! -- write information for each model
      if (this%convnmod > 1) then
        do j = 1, this%convnmod
          locdv = this%convlocdv(j, kpos)
          dv = this%convdvmax(j, kpos)
          locdr = this%convlocdr(j, kpos)
          dr = this%convdrmax(j, kpos)
          !
          ! -- get model number and user node number for dv
          call this%sln_get_nodeu(locdv, im, nodeu)
          write(iu, '(*(G0,:,","))', advance='NO') '', dv, nodeu
          !
          ! -- get model number and user node number for dr
          call this%sln_get_nodeu(locdr, im, nodeu)
          write(iu, '(*(G0,:,","))', advance='NO') '', dr, nodeu
        end do
      end if
      !
      ! -- write line
      write(iu,'(a)') ''
      !
      ! -- update itot
      itot = itot + 1
    end do
    !
    ! -- return
    return
  end subroutine csv_convergence_summary

  !> @ brief Save solution data to a file
  !!
  !!  Save solution ia vector, ja vector , coefficient matrix, right-hand side 
  !!  vector, and the dependent-variable vector to a file.
  !!
  !<
  subroutine save(this, filename)
    ! -- modules
    use InputOutputModule, only:getunit
    ! -- dummy variables
    class(NumericalSolutionType) :: this      !< NumericalSolutionType instance
    character(len=*), intent(in) :: filename  !< filename to save solution data
    ! -- local variables
    integer(I4B) :: inunit
! ------------------------------------------------------------------------------
    !
    inunit = getunit()
    open(unit=inunit,file=filename,status='unknown')
    write(inunit,*) 'ia'
    write(inunit,*) this%ia
    write(inunit,*) 'ja'
    write(inunit,*) this%ja
    write(inunit,*) 'amat'
    write(inunit,*) this%amat
    write(inunit,*) 'rhs'
    write(inunit,*) this%rhs
    write(inunit,*) 'x'
    write(inunit,*) this%x
    close(inunit)
    !
    ! -- return
    return
  end subroutine save

  !> @ brief Add a model
  !!
  !!  Add a model to s solution.
  !!
  !<
  subroutine add_model(this, mp)
    ! -- dummy variables
    class(NumericalSolutionType) :: this             !< NumericalSolutionType instance
    class(BaseModelType), pointer, intent(in) :: mp  !< model instance
    ! -- local variables
    class(NumericalModelType), pointer :: m => null()
    !
    ! -- add a model
    select type(mp)
    class is (NumericalModelType)
      m => mp
      call AddNumericalModelToList(this%modellist, m)
    end select
    !
    ! -- return
    return
  end subroutine add_model

  !> @brief Get a list of models
  !!
  !!  Returns a pointer to the list of models in this solution.
  !!
  !<
  function get_models(this) result(models)
    ! -- return variable
    type(ListType), pointer :: models    !< pointer to the model list
    ! -- dummy variables
    class(NumericalSolutionType) :: this !< NumericalSolutionType instance

    models => this%modellist

  end function get_models

  !> @brief Add exchange
  !!
  !!  Add and exchange to this%exchangelist.
  !!
  !<
  subroutine add_exchange(this, exchange)
    ! -- dummy variables
    class(NumericalSolutionType) :: this                       !< NumericalSolutionType instance
    class(BaseExchangeType), pointer, intent(in) :: exchange   !< model exchange instance
    ! -- local variables
    class(NumericalExchangeType), pointer :: num_ex => null()
    !
    ! -- add exchange
    select type(exchange)
    class is (NumericalExchangeType)
      num_ex => exchange
      call AddNumericalExchangeToList(this%exchangelist, num_ex)
    end select
    !
    ! -- return
    return
  end subroutine add_exchange

  !> @brief Returns a pointer to the list of exchanges in this solution
  !<
  function get_exchanges(this) result(exchanges)
    class(NumericalSolutionType) :: this !< instance of the numerical solution
    type(ListType), pointer :: exchanges    !< pointer to the exchange list

    exchanges => this%exchangelist

  end function get_exchanges
    
  !> @ brief Assign solution connections
  !!
  !!  Assign solution connections. This is the main workhorse method for a 
  !!  solution. The method goes through all the models and all the connections 
  !!  and builds up the sparse matrix. Steps are (1) add internal model 
  !!  connections, (2) add cross terms, (3) allocate solution arrays, (4) create
  !!  mapping arrays, and (5) fill cross term values if necessary.
  !!
  !<
  subroutine sln_connect(this)
    ! -- modules
    use MemoryManagerModule, only: mem_allocate
    ! -- dummy variables
    class(NumericalSolutionType) :: this   !< NumericalSolutionType instance
    ! -- local variables
    class(NumericalModelType), pointer :: mp => null()
    class(NumericalExchangeType), pointer :: cp => null()
    integer(I4B) :: im
    integer(I4B) :: ic
    integer(I4B) :: ierror
    !
    ! -- Add internal model connections to sparse
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_ac(this%sparse)
    enddo
    !
    ! -- Add the cross terms to sparse
    do ic=1,this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_ac(this%sparse)
    enddo
    !    
    ! -- The number of non-zero array values are now known so
    ! -- ia and ja can be created from sparse. then destroy sparse
    this%nja=this%sparse%nnz
    call mem_allocate(this%ja, this%nja, 'JA', this%name)
    call mem_allocate(this%amat, this%nja, 'AMAT', this%name)
    call this%sparse%sort()
    call this%sparse%filliaja(this%ia,this%ja,ierror)
    call this%sparse%destroy()
    !
    ! -- Create mapping arrays for each model.  Mapping assumes
    ! -- that each row has the diagonal in the first position,
    ! -- however, rows do not need to be sorted.
    do im=1,this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, im)
      call mp%model_mc(this%ia, this%ja)
    enddo
    !
    ! -- Create arrays for mapping exchange connections to global solution
    do ic=1,this%exchangelist%Count()
      cp => GetNumericalExchangeFromList(this%exchangelist, ic)
      call cp%exg_mc(this%ia, this%ja)
    enddo
    !
    ! -- return
    return
  end subroutine sln_connect

  !> @ brief Reset the solution
  !!
  !!  Reset the solution by setting the coefficient matrix and right-hand side 
  !!  vectors to zero.
  !!
  !<
  subroutine sln_reset(this)
    ! -- dummy variables
    class(NumericalSolutionType) :: this  !< NumericalSolutionType instance
    ! -- local variables
    integer(I4B) :: i
    !
    ! -- reset the solution
    do i = 1, this%nja
      this%amat(i) = DZERO
    end do
    do i = 1, this%neq
      this%rhs(i) = DZERO
    end do
    !
    ! -- return
    return
  end subroutine sln_reset

  !> @ brief Solve the linear system of equations
  !!
  !!  Solve the linear system of equations. Steps include (1) matrix cleanup,
  !!  (2) add pseudo-transient continuation terms, and (3) residual reduction.
  !!
  !<
  subroutine sln_ls(this, kiter, kstp, kper, in_iter, iptc, ptcf)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: kiter
    integer(I4B), intent(in) :: kstp
    integer(I4B), intent(in) :: kper
    integer(I4B), intent(inout) :: in_iter
    integer(I4B), intent(inout) :: iptc
    real(DP), intent(in) :: ptcf
    ! -- local variables
    logical :: lsame
    integer(I4B) :: n
    integer(I4B) :: itestmat
    integer(I4B) :: i
    integer(I4B) :: i1
    integer(I4B) :: i2
    integer(I4B) :: iptct
    integer(I4B) :: iallowptc
    real(DP) :: adiag
    real(DP) :: diagval
    real(DP) :: l2norm
    real(DP) :: ptcval
    real(DP) :: diagmin
    real(DP) :: bnorm
    character(len=50) :: fname
    character(len=*), parameter :: fmtfname = "('mf6mat_', i0, '_', i0, &
      &'_', i0, '_', i0, '.txt')"
    !
    ! -- take care of loose ends for all nodes before call to solver
    do n = 1, this%neq
      !
      ! -- store x in temporary location
      this%xtemp(n) = this%x(n)
      !
      ! -- set dirichlet boundary and no-flow condition
      if (this%active(n) <= 0) then
        this%amat(this%ia(n)) = DONE
        this%rhs(n) = this%x(n)
        i1 = this%ia(n) + 1
        i2 = this%ia(n + 1) - 1
        do i = i1, i2
          this%amat(i) = DZERO
        end do
      !
      ! -- take care of the case where there is a zero on the row diagonal
      else
        diagval = -DONE
        adiag = abs(this%amat(this%ia(n)))
        if (adiag < DEM15) then
          this%amat(this%ia(n)) = diagval
          this%rhs(n) = this%rhs(n) + diagval * this%x(n) 
        endif
      endif
    end do
    !
    ! -- pseudo transient continuation
    !
    ! -- set iallowptc
    ! -- no_ptc_option is FIRST
    if (this%iallowptc < 0) then
      if (kper > 1) then
        iallowptc = 1
      else
        iallowptc = 0
      end if
    !
    ! -- no_ptc_option is ALL (0) or using PTC (1)
    else
      iallowptc = this%iallowptc
    end if
    !
    ! -- set iptct
    iptct = iptc * iallowptc
    !
    ! -- calculate or modify pseudo transient continuation terms and add
    !    to amat diagonals
    if (iptct /= 0) then
      call this%sln_l2norm(this%neq, this%nja,                                 &
                           this%ia, this%ja, this%active,                      &
                           this%amat, this%rhs, this%x, l2norm)
      ! -- confirm that the l2norm exceeds previous l2norm
      !    if not, there is no need to add ptc terms
      if (kiter == 1) then
        if (kper > 1 .or. kstp > 1) then
          if (l2norm <= this%l2norm0) then
            iptc = 0
          end if
        end if
      else
        lsame = is_same(l2norm, this%l2norm0)
        if (lsame) then
          iptc = 0
        end if
      end if
    end if
    iptct = iptc * iallowptc
    if (iptct /= 0) then
      if (kiter == 1) then
        if (this%iptcout > 0) then
          write(this%iptcout, '(A10,6(1x,A15),2(1x,A15))') 'OUTER ITER',       &
            '         PTCDEL', '        L2NORM0', '         L2NORM',           &
            '        RHSNORM', '       1/PTCDEL', '  DIAGONAL MIN.',           &
            ' RHSNORM/L2NORM', ' STOPPING CRIT.'
        end if
        if (this%ptcdel0 > DZERO) then
          this%ptcdel = this%ptcdel0
        else
          if (this%iptcopt == 0) then
            !
            ! -- ptcf is the reciprocal of the pseudo-time step
            this%ptcdel = DONE / ptcf
          else
            bnorm = DZERO
            do n = 1, this%neq
              if (this%active(n).gt.0) then
                bnorm = bnorm + this%rhs(n) * this%rhs(n)
              end if
            end do
            bnorm = sqrt(bnorm)
            this%ptcdel = bnorm / l2norm
          end if
        end if
      else
        if (l2norm > DZERO) then
          this%ptcdel = this%ptcdel * (this%l2norm0 / l2norm)**this%ptcexp
        else
          this%ptcdel = DZERO
        end if
      end if
      if (this%ptcdel > DZERO) then
        ptcval = DONE / this%ptcdel
      else
        ptcval = DONE
      end if
      diagmin = DEP20
      bnorm = DZERO
      do n = 1, this%neq
        if (this%active(n) > 0) then
          diagval = abs(this%amat(this%ia(n)))
          bnorm = bnorm + this%rhs(n) * this%rhs(n)
          if (diagval < diagmin) diagmin = diagval
          this%amat(this%ia(n)) = this%amat(this%ia(n)) - ptcval
          this%rhs(n) = this%rhs(n) - ptcval * this%x(n)
        end if
      end do
      bnorm = sqrt(bnorm)
      if (this%iptcout > 0) then
        write(this%iptcout, '(i10,6(1x,e15.7),2(1x,f15.6))')                   &
          kiter, this%ptcdel, this%l2norm0, l2norm, bnorm,                     &
          ptcval, diagmin, bnorm/l2norm, ptcval / diagmin
      end if
      this%l2norm0 = l2norm
    end if
    !
    ! -- save rhs, amat to a file
    !    to enable set itestmat to 1 and recompile
    !-------------------------------------------------------
    itestmat = 0
    if (itestmat == 1) then
      write(fname, fmtfname) this%id, kper, kstp, kiter
      print *, 'Saving amat to: ', trim(adjustl(fname))
      open(99,file=trim(adjustl(fname)))
      WRITE(99,*)'NODE, RHS, AMAT FOLLOW'
      DO N = 1, this%NEQ
        I1 = this%IA(N)
        I2 = this%IA(N+1)-1
        WRITE(99,'(*(G0,:,","))') N, this%RHS(N), (this%ja(i),i=i1,i2), &
                      (this%AMAT(I),I=I1,I2)
      END DO
      close(99)
      !stop
    end if
    !-------------------------------------------------------
    !
    ! -- call appropriate linear solver
    !
    ! -- ims linear solver - linmeth option 1
    if (this%linmeth == 1) then
      call this%imslinear%imslinear_apply(this%icnvg, kstp, kiter, in_iter,    &
                                          this%nitermax,                       &
                                          this%convnmod, this%convmodstart,    &
                                          this%locdv, this%locdr,              &
                                          this%caccel, this%itinner,           &
                                          this%convlocdv, this%convlocdr,      &
                                          this%dvmax, this%drmax,              &
                                          this%convdvmax, this%convdrmax)
    end if
    !
    ! -- ptc finalize - set ratio of ptc value added to the diagonal and the
    !                   minimum value on the diagonal. This value will be used
    !                   to determine if the make sure the ptc value has decayed
    !                   sufficiently
    if (iptct /= 0) then
      this%ptcrat = ptcval / diagmin
    end if
    !
    ! -- return
    return
  end subroutine sln_ls

  !
  !> @ brief Set default Picard iteration variables
  !!
  !!  Set default Picard iteration variables based on passed complexity option.
  !!
  !<
  subroutine sln_setouter(this, ifdparam)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: ifdparam                 !< complexity option (1) simple (2) moderate (3) complex
    !
    ! -- simple option
    select case ( ifdparam )
    case ( 1 )
      this%dvclose = dem3
      this%mxiter = 25
      this%nonmeth = 0
      this%theta = DONE
      this%akappa = DZERO
      this%gamma = DONE
      this%amomentum = DZERO
      this%numtrack = 0
      this%btol = DZERO
      this%breduc = DZERO
      this%res_lim = DZERO
    !
    ! -- moderate
    case ( 2 )
      this%dvclose = dem2
      this%mxiter = 50
      this%nonmeth = 3
      this%theta = 0.9d0
      this%akappa = 0.0001d0
      this%gamma = DZERO
      this%amomentum = DZERO
      this%numtrack = 0
      this%btol = DZERO
      this%breduc = DZERO
      this%res_lim = DZERO
    !
    ! -- complex
    case ( 3 )
      this%dvclose = dem1
      this%mxiter = 100
      this%nonmeth = 3
      this%theta = 0.8d0
      this%akappa = 0.0001d0
      this%gamma = DZERO
      this%amomentum = DZERO
      this%numtrack = 20
      this%btol = 1.05d0
      this%breduc = 0.1d0
      this%res_lim = 0.002d0
    end select
    !
    ! -- return
    return
  end subroutine sln_setouter

  !> @ brief Perform backtracking
  !!
  !!  Perform backtracking on the solution in the maximum number of backtrack
  !!  iterations (nbtrack) is greater than 0 and the backtracking criteria 
  !!  are exceeded.
  !!
  !<
  subroutine sln_backtracking(this, mp, cp, kiter)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    class(NumericalModelType), pointer :: mp             !< model pointer (currently null())
    class(NumericalExchangeType), pointer :: cp          !< exchange pointer (currently null())
    integer(I4B), intent(in) :: kiter                    !< Picard iteration number
    ! -- local variables
    character(len=7) :: cmsg
    integer(I4B) :: nb
    integer(I4B) :: btflag
    integer(I4B) :: ibflag
    integer(I4B) :: ibtcnt
    real(DP) :: resin
    !
    ! -- initialize local variables
    ibflag = 0
    
    !
    ! -- refill amat and rhs with standard conductance
    call this%sln_buildsystem(kiter, inewton=0)
       
    !
    ! -- calculate initial l2 norm
    if (kiter == 1) then
      call this%sln_l2norm(this%neq, this%nja,                                 &
                            this%ia, this%ja, this%active,                     &
                            this%amat, this%rhs, this%x, this%res_prev)
      resin = this%res_prev
      ibflag = 0
    else
      call this%sln_l2norm(this%neq, this%nja,                                 &
                            this%ia, this%ja, this%active,                     &
                            this%amat, this%rhs, this%x, this%res_new)
      resin = this%res_new
    end if
    ibtcnt = 0
    if (kiter > 1) then
      if (this%res_new > this%res_prev * this%btol) then
        !
        ! -- iterate until backtracking complete
        btloop: do nb = 1, this%numtrack
          !
          ! -- backtrack the dependent variable
          call this%sln_backtracking_xupdate(btflag)
          !
          ! -- dependent-variable change less than dvclose
          if (btflag == 0) then
            ibflag = 4
            exit btloop
          end if
          !
          ibtcnt = nb
          
          ! recalculate linear system (amat and rhs)
          call this%sln_buildsystem(kiter, inewton=0)
                    
          !
          ! -- calculate updated l2norm
          call this%sln_l2norm(this%neq, this%nja,                             &
                               this%ia, this%ja, this%active,                  &
                                this%amat, this%rhs, this%x, this%res_new)
          !
          ! -- evaluate if back tracking can be terminated
          if (nb == this%numtrack) then
            ibflag = 2
            exit btloop
          end if
          if (this%res_new < this%res_prev * this%btol) then
              ibflag = 1
            exit btloop
          end if
          if (this%res_new < this%res_lim) then
            exit btloop
          end if
        end do btloop
      end if
      ! -- save new residual
      this%res_prev = this%res_new
    end if
    !
    ! -- write back backtracking results
    if (this%iprims > 0) then
      if (ibtcnt > 0) then
        cmsg = ' '
      else
        cmsg = '*'
      end if
      !
      ! -- add data to outertab
      call this%outertab%add_term( 'Backtracking')
      call this%outertab%add_term(kiter)
      call this%outertab%add_term(' ')
      if (this%numtrack > 0) then
        call this%outertab%add_term(ibflag)
        call this%outertab%add_term(ibtcnt)
        call this%outertab%add_term(resin)
        call this%outertab%add_term(this%res_prev)
      end if
      call this%outertab%add_term(' ')
      call this%outertab%add_term(cmsg)
      call this%outertab%add_term(' ')
    end if
    !
    ! -- return
    return
  end subroutine sln_backtracking

  !> @ brief Backtracking update of the dependent variable
  !!
  !!  Backtracking update of the dependent variable if the calculated backtracking
  !!  update exceeds the dependent variable closure critera.
  !!
  !<
  subroutine sln_backtracking_xupdate(this, btflag)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this !< NumericalSolutionType instance
    integer(I4B), intent(inout) :: btflag               !< backtracking flag (1) backtracking performed (0) backtracking not performed
    ! -- local variables
    integer(I4B) :: n
    real(DP) :: delx
    real(DP) :: absdelx
    real(DP) :: chmax
    !
    ! -- initialize dummy variables
    btflag = 0
    !
    ! -- no backtracking if maximum change is less than closure so return
    chmax = 0.0
    do n = 1, this%neq
      if (this%active(n) < 1) cycle
      delx = this%breduc*(this%x(n) - this%xtemp(n))
      absdelx = abs(delx)
      if (absdelx > chmax) chmax = absdelx
    end do
    !
    ! -- perform backtracking if free of constraints and set counter and flag
    if (chmax >= this%dvclose) then
      btflag = 1
      do n = 1, this%neq
        if (this%active(n) < 1) cycle
        delx = this%breduc*(this%x(n) - this%xtemp(n))
        this%x(n) = this%xtemp(n) + delx
      end do
    end if
    !
    ! -- return
    return
  end subroutine sln_backtracking_xupdate

  !> @ brief Calculate the solution L-2 norm
  !!
  !!  Calculate the solution L-2 norm using the coefficient matrix, the
  !!  right-hand side vector, and the current dependent-variable vector.
  !!
  !<
  subroutine sln_l2norm(this, neq, nja, ia, ja, active, amat, rhs, x, l2norm)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: neq                      !< number of equations
    integer(I4B), intent(in) :: nja                      !< number of non-zero entries
    integer(I4B), dimension(neq+1), intent(in) :: ia     !< CRS row pointers
    integer(I4B), dimension(nja), intent(in) :: ja       !< CRS column pointers
    integer(I4B), dimension(neq), intent(in) :: active   !< active cell flag vector (1) inactive (0)
    real(DP), dimension(nja), intent(in) :: amat         !< coefficient matrix
    real(DP), dimension(neq), intent(in) :: rhs          !< right-hand side vector
    real(DP), dimension(neq), intent(in) :: x            !< dependent-variable vector
    real(DP), intent(inout) :: l2norm                    !< calculated L-2 norm
    ! -- local variables
    integer(I4B) :: n
    integer(I4B) :: j
    integer(I4B) :: jcol
    real(DP) :: rowsum
    real(DP) :: residual
    !
    ! -- initialize local variables
    residual = DZERO
    !
    ! -- calculate the L-2 norm
    do n = 1, neq
      if (active(n) > 0) then
        rowsum = DZERO
        do j = ia(n), ia(n+1)-1
          jcol = ja(j)
          rowsum = rowsum + amat(j) * x(jcol)
        end do
        ! compute mean square residual from q of each node
        residual = residual + (rowsum - rhs(n))**2
      end if
    end do
    ! -- The L-2 norm is the square root of the sum of the square of the residuals
    l2norm = sqrt(residual)
    !
    ! -- return
    return
  end subroutine sln_l2norm

  !> @ brief Get the maximum value from a vector
  !!
  !!  Return the maximum value in a vector using a normalized form.
  !!
  !<
  subroutine sln_maxval(this, nsize, v, vmax)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: nsize                    !< length of vector
    real(DP), dimension(nsize), intent(in) :: v          !< input vector
    real(DP), intent(inout) :: vmax                      !< maximum value
    ! -- local variables
    integer(I4B) :: n
    real(DP) :: d
    real(DP) :: denom
    real(DP) :: dnorm
    !
    ! -- determine maximum value
    vmax = v(1)
    do n = 2, nsize
      d = v(n)
      denom = abs(vmax)
      if (denom == DZERO) then
        denom = DPREC
      end if
      !
      ! -- calculate normalized value
      dnorm = abs(d) / denom
      if (dnorm > DONE) then
        vmax = d
      end if
    end do
    !
    ! -- return
    return
  end subroutine sln_maxval

  !> @ brief Calculate dependent-variable change
  !!
  !!  Calculate the dependent-variable change for every cell.
  !!
  !<
  subroutine sln_calcdx(this, neq, active, x, xtemp, dx)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: neq                      !< number of equations
    integer(I4B), dimension(neq), intent(in) :: active   !< active cell flag (1)
    real(DP), dimension(neq), intent(in) :: x            !< current dependent-variable 
    real(DP), dimension(neq), intent(in) :: xtemp        !< previous dependent-variable
    real(DP), dimension(neq), intent(inout) :: dx        !< dependent-variable change
    ! -- local
    integer(I4B) :: n
    !
    ! -- calculate dependent-variable change
    do n = 1, neq
      ! -- skip inactive nodes
      if (active(n) < 1) then
        dx(n) = DZERO
      else
        dx(n) = x(n) - xtemp(n)
      end if
    end do
    !
    ! -- return
    return
  end subroutine sln_calcdx


  !> @ brief Under-relaxation
  !!
  !!  Under relax using the simple, cooley, or delta-bar-delta methods.
  !!
  !<
  subroutine sln_underrelax(this, kiter, bigch, neq, active, x, xtemp)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: kiter                    !< Picard iteration number
    real(DP), intent(in) :: bigch                        !< maximum dependent-variable change
    integer(I4B), intent(in) :: neq                      !< number of equations
    integer(I4B), dimension(neq), intent(in) :: active   !< active cell flag (1)
    real(DP), dimension(neq), intent(inout) :: x         !< current dependent-variable
    real(DP), dimension(neq), intent(in) :: xtemp        !< previous dependent-variable
    ! -- local variables
    integer(I4B) :: n
    real(DP) :: ww
    real(DP) :: delx
    real(DP) :: relax
    real(DP) :: es
    real(DP) :: aes
    real(DP) :: amom
! ------------------------------------------------------------------------------
    !
    ! -- option for using simple dampening (as done by MODFLOW-2005 PCG)
    if (this%nonmeth == 1) then
      do n = 1, neq
        !
        ! -- skip inactive nodes
        if (active(n) < 1) cycle
        !
        ! -- compute step-size (delta x)
        delx = x(n) - xtemp(n)
        this%dxold(n) = delx

        ! -- dampen dependent variable solution
        x(n) = xtemp(n) + this%gamma * delx
      end do
    !
    ! -- option for using cooley underrelaxation
    else if (this%nonmeth == 2) then
      !
      ! -- set bigch
      this%bigch = bigch
      !
      ! -- initialize values for first iteration
      if (kiter == 1) then
        relax = DONE
        this%relaxold = DONE
        this%bigchold = bigch
      else
        !
        ! -- compute relaxation factor
        es = this%bigch / (this%bigchold * this%relaxold)
        aes = abs(es)
        if (es < -DONE) then
          relax = dhalf / aes
        else
          relax = (DTHREE + es) / (DTHREE + aes)
        end if
      end if
      this%relaxold = relax
      !
      ! -- modify cooley to use weighted average of past changes
      this%bigchold = (DONE - this%gamma) * this%bigch  + this%gamma *         &
                      this%bigchold
      !
      ! -- compute new dependent variable after under-relaxation
      if (relax < DONE) then
        do n = 1, neq
          !
          ! -- skip inactive nodes
          if (active(n) < 1) cycle
          !
          ! -- update dependent variable
          delx = x(n) - xtemp(n)
          this%dxold(n) = delx
          x(n) = xtemp(n) + relax * delx
        end do
      end if
    !
    ! -- option for using delta-bar-delta scheme to under-relax for all equations
    else if (this%nonmeth == 3) then
      do n = 1, neq
        !
        ! -- skip inactive nodes
        if (active(n) < 1) cycle
        !
        ! -- compute step-size (delta x) and initialize d-b-d parameters
        delx = x(n) - xtemp(n)
        !
        ! -- initialize values for first iteration
        if ( kiter == 1 ) then
          this%wsave(n) = DONE
          this%hchold(n) = DEM20
          this%deold(n) = DZERO
        end if
        !
        ! -- compute new relaxation term as per delta-bar-delta
        ww = this%wsave(n)
        !
        ! for flip-flop condition, decrease factor
        if ( this%deold(n)*delx < DZERO ) then
          ww = this%theta * this%wsave(n)
          ! -- when change is of same sign, increase factor
        else
          ww = this%wsave(n) + this%akappa
        end if
        if ( ww > DONE ) ww = DONE
        this%wsave(n) = ww
        !
        ! -- compute weighted average of past changes in hchold
        if (kiter == 1) then
          this%hchold(n) = delx
        else
          this%hchold(n) = (DONE - this%gamma) * delx +                        &
                           this%gamma * this%hchold(n)
        end if
        !
        ! -- store slope (change) term for next iteration
        this%deold(n) = delx
        this%dxold(n) = delx
        !
        ! -- compute accepted step-size and new dependent variable
        amom = DZERO
        if (kiter > 4) amom = this%amomentum
        delx = delx * ww + amom * this%hchold(n)
        x(n) = xtemp(n) + delx
      end do
      !
    end if
    !
    ! -- return
    return
  end subroutine sln_underrelax

  !> @ brief Determine maximum dependent-variable change
  !!
  !!  Determine the maximum dependent-variable change at the end of a 
  !!  Picard iteration.
  !!
  !<
  subroutine sln_outer_check(this, hncg, lrch)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    real(DP), intent(inout) :: hncg                      !< maximum dependent-variable change
    integer(I4B), intent(inout) :: lrch                  !< location of the maximum dependent-variable change
    ! -- local variables
    integer(I4B) :: nb
    real(DP) :: bigch
    real(DP) :: abigch
    integer(I4B) :: n
    real(DP) :: hdif
    real(DP) :: ahdif
    !
    ! -- determine the maximum change
    nb = 1
    bigch = DZERO
    abigch = DZERO
    do n = 1, this%neq
      if(this%active(n) < 1) cycle
      hdif = this%x(n) - this%xtemp(n)
      ahdif = abs(hdif)
      if (ahdif >= abigch) then
        bigch = hdif
        abigch = ahdif
        nb = n
      end if
    end do
    !
    !-----store maximum change value and location
    hncg = bigch
    lrch = nb
    !
    ! -- return
    return
  end subroutine sln_outer_check

  !> @ brief Get cell location string
  !!
  !!  Get the cell location string for the provided solution node number.
  !!
  !<
  subroutine sln_get_loc(this, nodesln, str)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: nodesln                  !< solution node number
    character(len=*), intent(inout) :: str               !< string with user node number
    ! -- local variables
    class(NumericalModelType), pointer :: mp=> null()
    integer(I4B) :: i
    integer(I4B) :: istart
    integer(I4B) :: iend
    integer(I4B) :: noder
    !
    ! -- initialize dummy variables
    str = ''
    !
    ! -- initialize local variables
    noder = 0
    !
    ! -- calculate and set offsets
    do i = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, i)
      istart = 0
      iend = 0
      call mp%get_mrange(istart, iend)
      if (nodesln >= istart .and. nodesln <= iend) then
        noder = nodesln - istart + 1
        call mp%get_mcellid(noder, str)
        exit
      end if
    end do
    !
    ! -- return
    return
  end subroutine sln_get_loc

  !> @ brief Get user node number
  !!
  !!  Get the user node number from a model for the provided solution node number.
  !!
  !<
  subroutine sln_get_nodeu(this, nodesln, im, nodeu)
    ! -- dummy variables
    class(NumericalSolutionType), intent(inout) :: this  !< NumericalSolutionType instance
    integer(I4B), intent(in) :: nodesln                  !< solution node number
    integer(I4B), intent(inout) :: im                    !< solution model number
    integer(I4B), intent(inout) :: nodeu                 !< user node number
    ! -- local variables
    class(NumericalModelType),pointer :: mp => null()
    integer(I4B) :: i
    integer(I4B) :: istart
    integer(I4B) :: iend
    integer(I4B) :: noder
    !
    ! -- initialize local variables
    noder = 0
    !
    ! -- calculate and set offsets
    do i = 1, this%modellist%Count()
      mp => GetNumericalModelFromList(this%modellist, i)
      istart = 0
      iend = 0
      call mp%get_mrange(istart, iend)
      if (nodesln >= istart .and. nodesln <= iend) then
        noder = nodesln - istart + 1
        call mp%get_mnodeu(noder, nodeu)
        im = i
        exit
      end if
    end do
    !
    ! -- return
    return
  end subroutine sln_get_nodeu

  !> @ brief Cast a object as a Numerical Solution
  !!
  !!  Get a numerical solution from a list.
  !!
  !<
  function CastAsNumericalSolutionClass(obj) result (res)
    ! -- dummy variables
    class(*), pointer, intent(inout) :: obj         !< generic object
    ! -- return variable
    class(NumericalSolutionType), pointer :: res    !< output NumericalSolutionType
    !
    ! -- initialize return variable
    res => null()
    !
    ! -- determine if obj is associated
    if (.not. associated(obj)) return
    !
    ! -- set res
    select type (obj)
    class is (NumericalSolutionType)
      res => obj
    end select
    !
    ! -- return
    return
  end function CastAsNumericalSolutionClass
  
  !> @ brief Get a numerical solution
  !!
  !!  Get a numerical solution from a list.
  !!
  !<
  function GetNumericalSolutionFromList(list, idx) result (res)
    ! -- dummy variables
    type(ListType), intent(inout) :: list         !< list of numerical solutions
    integer(I4B), intent(in)    :: idx            !< value to retrieve from the list
    ! -- return variables
    class(NumericalSolutionType), pointer :: res  !< numerical solution
    ! -- local variables
    class(*), pointer :: obj
    !
    obj => list%GetItem(idx)
    res => CastAsNumericalSolutionClass(obj)
    !
    return
  end function GetNumericalSolutionFromList
end module NumericalSolutionModule
