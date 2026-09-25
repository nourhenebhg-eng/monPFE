<nav class="navbar navbar-expand navbar-light navbar-bg">
  <a class="sidebar-toggle js-sidebar-toggle">
    <i class="hamburger align-self-center"></i>
  </a>

  <ul class="navbar-nav navbar-align">


  <div class="navbar-collapse collapse">
    <ul class="navbar-nav navbar-align">


      <li class="nav-item dropdown">
        <a class="nav-icon dropdown-toggle d-inline-block d-sm-none" href="#" data-bs-toggle="dropdown">
          <i class="align-middle" data-feather="settings"></i>
        </a>
        <a class="nav-link dropdown-toggle d-none d-sm-inline-block" href="#" data-bs-toggle="dropdown">
          <img src="{{ asset('img/avatars/dummy.png') }}" class="avatar img-fluid rounded me-1" alt="Charles Hall" /> <span class="text-dark">{{ Auth::user()->name }}</span>
        </a>
        <div class="dropdown-menu dropdown-menu-end">
          <a class="dropdown-item" href="javascript:void(0)"><i class="align-middle me-1" data-feather="user"></i> Profile</a>
          <a class="dropdown-item" href="javascript:void(0)"><i class="align-middle me-1" data-feather="pie-chart"></i> Analytics</a>
          <div class="dropdown-divider"></div>
          <a class="dropdown-item" href="javascript:void(0)"><i class="align-middle me-1" data-feather="settings"></i> Settings & Privacy</a>
          <a class="dropdown-item" href="javascript:void(0)"><i class="align-middle me-1" data-feather="help-circle"></i> Help Center</a>
          <div class="dropdown-divider"></div>
          {{-- <a class="dropdown-item" href="javascript:void(0)">Log out</a> --}}
          <!-- Authentication -->
          <form method="POST" action="{{ route('logout') }}">
            @csrf
            <a class="dropdown-item" href="route('logout')" onclick="event.preventDefault(); this.closest('form').submit();">
              <i class="align-middle me-1" data-feather="log-out"></i>
              <span class="me-1">{{ __('Log Out') }}</span>
            </a>
          </form>
        </div>
      </li>
    </ul>
  </div>
</nav>