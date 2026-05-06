export const formatISOToCustom = (isoString: string) => {
    const date = new Date(isoString);

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');

    const day = date.getDate();
    const month = months[date.getMonth()];
    const year = date.getFullYear();

    return `${hours}:${minutes}:${seconds} ${day} ${month}, ${year}`;
};
