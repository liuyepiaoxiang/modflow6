!> @brief This module contains message methods
!!
!! This module contains generic message methods that are used to 
!! create warning and error messages and notes. This module also has methods
!! for counting messages. The module does not have any dependencies on 
!! models, exchanges, or solutions in a simulation.
!!
!<
module MessageModule
  
  use KindModule, only: LGP, I4B, DP
  use ConstantsModule, only: LINELENGTH, MAXCHARLEN, DONE,                       &
                             VSUMMARY
  use GenericUtilitiesModule, only: sim_message  
  use SimVariablesModule,     only: istdout
  use ArrayHandlersModule, only: ExpandArray  
  
  implicit none
  
  public :: MessageType
  
  type :: MessageType

    character(len=LINELENGTH) :: title                               !< title of the message 
    character(len=LINELENGTH) :: name                                !< message name
    integer(I4B) :: nmessage = 0                                     !< number of messages stored
    integer(I4B) :: max_message = 1000                               !< default maximum number of messages that can be stored
    integer(I4B) :: max_exceeded = 0                                 !< flag indicating if the maximum number of messages has exceed the maximum number
    integer(I4B) :: inc_message = 100                                !< amount to increment message array by when calling ExpandArray
    character(len=MAXCHARLEN), allocatable, dimension(:) :: message  !< message array
    
    contains
  
    procedure :: init_message
    procedure :: count_message
    procedure :: set_max_message
    procedure :: store_message
    procedure :: print_message
    procedure :: deallocate_message

  end type MessageType
  
  contains

    !> @brief Always initialize the message object
    !!
    !! Subroutine that initializes the message object. Allocation of message 
    !! array occurs on-the-fly.
    !!
    !<
    subroutine init_message(this)
      ! -- dummy variables
      class(MessageType) :: this  !< MessageType object
      !
      ! -- initialize message variables
      this%nmessage = 0
      this%max_message = 1000
      this%max_exceeded = 0
      this%inc_message = 100
      !
      ! -- return
      return
    end subroutine init_message
  
    !> @brief Return number of messages
    !!
    !!  Function to return the number of messages that have been stored.
    !!
    !!  @return  ncount number of messages stored
    !!
    !<
    function count_message(this) result(nmessage)
      ! -- dummy variables
      class(MessageType) :: this     !< MessageType object
      ! -- return variable
      integer(I4B) :: nmessage
      !
      ! -- set nmessage
      if (allocated(this%message)) then
        nmessage = this%nmessage
      else
        nmessage = 0
      end if
      !
      ! -- return
      return
    end function count_message
    
    !> @brief Set the maximum number of messages stored
    !!
    !!  Subroutine to set the maximum number of messages that will be stored
    !!  in a simulation.
    !!
    !<
    subroutine set_max_message(this, imax)
      ! -- dummy variables
      class(MessageType) :: this           !< MessageType object
      integer(I4B), intent(in) :: imax     !< maximum number of messages that will be stored
      !
      ! -- set max_message
      this%max_message = imax
      !
      ! -- return
      return
    end subroutine set_max_message
    
    !> @brief Store message
    !!
    !!  Subroutine to store a message for printing at the end of
    !!  the simulation.
    !!
    !<
    subroutine store_message(this, msg, substring)
      ! -- dummy variables
      class(MessageType) :: this                           !< MessageType object
      character(len=*), intent(in) :: msg                  !< message
      character(len=*), intent(in), optional :: substring  !< optional string that can be used 
                                                           !! to prevent storing duplicate messages 
      ! -- local variables
      logical(LGP) :: inc_array
      logical(LGP) :: increment_message
      integer(I4B) :: i
      integer(I4B) :: idx
      !
      ! -- determine if messages should be expanded
      inc_array = .TRUE.
      if (allocated(this%message)) then
        i = this%nmessage
        if (i < size(this%message)) then
          inc_array = .FALSE.
        end if
      end if
      !
      ! -- resize message
      if (inc_array) then
        call ExpandArray(this%message, increment=this%inc_message)
        this%inc_message = int(this%inc_message * 1.1)
      end if
      !
      ! -- Determine if the substring exists in the passed message.
      !    If substring is in passed message, do not add the duplicate 
      !    passed message.
      increment_message = .TRUE.
      if (present(substring)) then
        do i = 1, this%nmessage
          idx = index(this%message(i), substring)
          if (idx > 0) then
            increment_message = .FALSE.
            exit
          end if
        end do
      end if
      !
      ! -- store this message and calculate nmessage
      if (increment_message) then
        i = this%nmessage + 1
        if (i <= this%max_message) then
          this%nmessage = i
          this%message(i) = msg
        else
          this%max_exceeded = this%max_exceeded + 1
        end if
      end if
      !
      ! -- return
      return
    end subroutine store_message
    
    !> @brief Print messages
    !!
    !!  Subroutine to print stored messages.
    !!
    !<
    subroutine print_message(this, title, name, iunit, level)
      ! -- dummy variables
      class(MessageType) :: this                   !< MessageType object
      character(len=*), intent(in) :: title        !< message title
      character(len=*), intent(in) :: name         !< message name
      integer(I4B), intent(in), optional :: iunit  !< optional file unit to save messages to
      integer(I4B), intent(in), optional :: level  !< optional level of messages to print
      ! -- local
      character(len=LINELENGTH) :: errmsg
      character(len=LINELENGTH) :: cerr
      integer(I4B) :: iu
      integer(I4B) :: ilevel
      integer(I4B) :: i
      integer(I4B) :: isize
      integer(I4B) :: iwidth
      ! -- formats
      character(len=*), parameter :: stdfmt = "(/,A,/)"
      !
      ! -- process optional variables
      if (present(iunit)) then
        iu = iunit
      else
        iu = 0
      end if
      if (present(level)) then
        ilevel = level
      else
        ilevel = VSUMMARY
      end if
      !
      ! -- write the title and all message entries
      if (allocated(this%message)) then
        isize = this%nmessage
        if (isize > 0) then
          !
          ! -- calculate the maximum width of the prepended string
          !    for the counter
          write(cerr, '(i0)') isize
          iwidth = len_trim(cerr) + 1
          !
          ! -- write title for message
          if (iu > 0) then
            call sim_message(title, iunit=iu, fmt=stdfmt, level=ilevel)
          end if
          call sim_message(title, fmt=stdfmt, level=ilevel)
          !
          ! -- write each message
          do i = 1, isize
            call write_message(this%message(i), i, iwidth=iwidth, level=ilevel)
            if (iu > 0) then
              call write_message(this%message(i), i, iwidth=iwidth, iunit=iu,    &
                                 level=ilevel)
            end if
          end do
          !
          ! -- write the number of additional messages
          if (this%max_exceeded > 0) then
            write(errmsg, '(i0,3(1x,a))')                                        &
              this%max_exceeded, 'additional', trim(name),                       &
              'detected but not printed.'
            call sim_message(trim(errmsg), fmt='(/,1x,a)', level=ilevel)
            if (iu > 0) then
              call sim_message(trim(errmsg), iunit=iu, fmt='(/,1x,a)',           &
                               level=ilevel)
            end if
          end if
        end if
      end if
      !
      ! -- return
      return
    end subroutine print_message

    !> @brief Write messages
    !!
    !!  Subroutine that formats and writes a single message.
    !!
    !<
    subroutine write_message(message, icount, iwidth, iunit, level)
    ! -- dummy variables
    character (len=*), intent(in)           :: message   !< message to be written
    integer(I4B),      intent(in)           :: icount    !< counter to prepended to the message  
    integer(I4B),      intent(in)           :: iwidth    !< maximum width of the prepended counter
    integer(I4B),      intent(in), optional :: iunit     !< the unit number to which the message is written
    integer(I4B),      intent(in), optional :: level     !< level of message (VSUMMARY, VALL, VDEBUG)
    ! -- local variables
    character(len=MAXCHARLEN) :: amessage
    character(len=20)         :: ablank
    character(len=16)         :: cfmt
    character(len=10)         :: cval
    integer(I4B)              :: jend
    integer(I4B)              :: nblc
    integer(I4B)              :: junit
    integer(I4B)              :: ilevel
    integer(I4B)              :: leadblank
    integer(I4B)              :: itake
    integer(I4B)              :: ipos
    integer(I4B)              :: i
    integer(I4B)              :: j
    !
    ! -- return if no message is passed
    if (len_trim(message) < 1) then
      return
    end if
    !
    ! -- initialize local variables
    amessage = message
    junit = istdout
    ablank = ' '
    itake = 0
    j = 0
    !
    ! -- ensure that there is at least one blank space at the start of amessage
    if (amessage(1:1) /= ' ') then
      amessage = ' ' // trim(amessage)
    end if
    !
    ! -- process optional dummy variables
    ! -- set the unit number
    if(present(iunit))then
      if (iunit > 0) then
        junit = iunit
      end if
    end if
    !
    ! -- set the message level
    if (present(level)) then
      ilevel = level
    else
      ilevel = VSUMMARY
    end if
    !
    ! -- create the counter to prepend to amessage
    write(cfmt, '(A,I0,A)') '(1X,I', iwidth, ',".")'
    write(cval, cfmt) icount
    !
    ! -- prepend amessage with the counter
    ipos = len_trim(cval)
    nblc = len_trim(amessage)
    amessage = adjustr(amessage(1:nblc+ipos))
    if (nblc+ipos < len(amessage)) then
      amessage(nblc+ipos+1:) = ' '
    end if
    amessage(1:ipos) = cval(1:ipos)
    !
    ! -- set the number of leading blanks
    leadblank = ipos - 1
    !
    ! -- calculate the final length of the message after modification
    nblc = len_trim(amessage)
    !
    ! -- parse the amessage into multiple lines
5   continue
    jend = j + 78 - itake
    if (jend >= nblc) go to 100
    do i = jend, j+1, -1
      if (amessage(i:i).eq.' ') then
        if (itake.eq.0) then
          call sim_message(amessage(j+1:i), iunit=junit, level=ilevel)
          itake = 2 + leadblank
        else
          call sim_message(ablank(1:leadblank+2)//amessage(j+1:i),               &
                           iunit=junit, level=ilevel)
        end if
        j = i
        go to 5
      end if
    end do
    if (itake == 0)then
      call sim_message(amessage(j+1:jend), iunit=junit, level=ilevel)
      itake = 2 + leadblank
    else
      call sim_message(ablank(1:leadblank+2)//amessage(j+1:jend),                &
                       iunit=junit, level=ilevel)
    end if
    j = jend
    go to 5
    !
    ! -- last piece of amessage to write to a line
100 continue
    jend = nblc
    if (itake == 0)then
      call sim_message(amessage(j+1:jend), iunit=junit, level=ilevel)
    else
      call sim_message(ablank(1:leadblank+2)//amessage(j+1:jend),                &
                       iunit=junit, level=ilevel)
    end if
    !
    ! -- return
    return
  end subroutine write_message
    
  !> @ brief Deallocate message
  !!
  !! Subroutine that deallocate the array of strings if it was allocated 
  !!
  !<
  subroutine deallocate_message(this)
    ! -- dummy variables
    class(MessageType) :: this    !< MessageType object
    !
    ! -- deallocate the message
    if (allocated(this%message)) then
      deallocate(this%message)
    end if
    !
    ! -- return
    return
  end subroutine deallocate_message

end module MessageModule
