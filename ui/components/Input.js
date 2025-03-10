import React from 'react';

export const Input = ({ value, onChange, placeholder }) => {
  return (
    <input
      className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
      type="text"
      value={value}
      onChange={onChange}
      placeholder={placeholder}
    />
  );
};