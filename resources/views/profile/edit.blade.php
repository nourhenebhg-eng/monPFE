<div class="col-6">
    <label for="basic">{{ __('Basic Salary') }}</label>
    <input
        type="number"
        name="basic"
        class="form-control"
        id="basic"
        step="0.01"
        min="0"
        value="{{ $employee->salary->basic ?? 0 }}"
        required
    >
</div>